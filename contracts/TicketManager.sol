// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.28;

// =================================================================
// 1. ESTRUCTURAS DE UTILIDAD (Enums y Structs)
// =================================================================

enum TicketType {
  Novice,
  NoviceII,
  Advanced,
  Expert,
  Professional
}

struct Variant {
  TicketType ticketType;
  uint256 ticketPrice;
  string ticketName;
  string ticketColor;
}

struct Ticket {
  address owner;
  TicketType variant;
  bool isUsed;
}

// =================================================================
// 2. DECLARACIÓN DEL CONTRATO
// =================================================================

contract TicketManager {
  // =================================================================
  // 3. VARIABLES DE ESTADO (Globales y Mapeos)
  // =================================================================

  address public contractOwner;
  // ABSTRACCIÓN: Autorización para cualquier juego (HashPool u otro)
  mapping(address => bool) public authorizedGames;
  uint256 public platformFeeBasisPoints;
  uint256 nextId = 1;

  // SEGURIDAD CRÍTICA: Rastra el valor total de los tickets consumidos por cada juego.
  // Esta es la cantidad MÁXIMA que el juego puede solicitar en premios.
  mapping(address => uint256) public totalValueConsumed;

  // Mapeos
  mapping(uint256 => Ticket) tickets;
  mapping(address => uint256[]) ticketOwners;
  mapping(TicketType => Variant) variants;
  mapping(string => TicketType) public stringToTicketType;

  // =================================================================
  // 4. EVENTOS
  // =================================================================

  event FeeAdded(uint256 amount);
  event PurchasedTicket(address owner, uint256 value, uint256 ticketId);
  // El evento TicketConsumed no necesita modificarse, pero su función sí añade valor.
  event TicketConsumed(
    uint256 ticketId,
    address user,
    address consumingContract
  );
  event TicketStatusReverted(
    uint256 ticketId,
    address user,
    address consumingContract
  );
  event PrizeAwarded(
    address indexed winner,
    uint256 netPrize,
    uint256 feeAmount
  );
  // ABSTRACCIÓN: Renombrado el evento de autorización.
  event GameAuthorized(address indexed contractGameAddress);

  // =================================================================
  // 5. MODIFICADORES
  // =================================================================

  modifier onlyOwner() {
    require(msg.sender == contractOwner, 'Solo el propietario es el gestor.');
    _;
  }

  // ABSTRACCIÓN: Renombrado el modificador.
  modifier onlyAuthorizedGames() {
    require(
      authorizedGames[msg.sender],
      'Solo un juego autorizado puede llamar.'
    );
    _;
  }

  // =================================================================
  // 6. CONSTRUCTOR
  // =================================================================

  constructor(
    string[] memory _ticketNames,
    uint256[] memory _ticketPrices,
    string[] memory _ticketColorsForVariants,
    uint256 _feePercentage
  ) {
    uint256 numTicketTypes = uint256(TicketType.Professional) + 1;

    require(
      _ticketNames.length == numTicketTypes &&
        _ticketPrices.length == numTicketTypes &&
        _ticketColorsForVariants.length == numTicketTypes,
      'Error: informacion incompleta para tipos de tickets o colores.'
    );

    for (uint256 i = 0; i < numTicketTypes; i++) {
      TicketType currentType = TicketType(i);
      stringToTicketType[_ticketNames[i]] = currentType;
      variants[currentType] = Variant(
        currentType,
        _ticketPrices[i],
        _ticketNames[i],
        _ticketColorsForVariants[i]
      );
    }

    contractOwner = payable(msg.sender);
    platformFeeBasisPoints = _feePercentage;
  }

  // =================================================================
  // 7. FUNCIONES MUTABLES (SETTERS, Transacciones, Lógica)
  // =================================================================

  /**
   * @notice Autoriza un nuevo contrato de juego (HashPool u otro) para interactuar con este Manager.
   */
  function authorizeGame(address _poolAddress) public onlyOwner {
    require(_poolAddress != address(0), 'Direccion del Pool invalida.');
    require(!authorizedGames[_poolAddress], 'El Pool ya esta autorizado.');

    authorizedGames[_poolAddress] = true;

    emit GameAuthorized(_poolAddress);
  }

  function depositEmergencyFunds() public payable onlyOwner {
    // Permite al dueño enviar fondos de emergencia al contrato
  }

  function setPlatformFee(uint256 newFee) public onlyOwner {
    require(newFee <= 1000, 'Fee no puede exceder el 10% (1000 BPS)');
    platformFeeBasisPoints = newFee;
    emit FeeAdded(newFee);
  }

  function buy(string memory ticketName) public payable {
    TicketType currentType = stringToTicketType[ticketName];
    Variant memory requestedVariant = variants[currentType];

    require(
      requestedVariant.ticketPrice > 0,
      'Error: La variante de ticket proporcionada no existe en este contrato.'
    );

    require(
      msg.value == requestedVariant.ticketPrice,
      'La cantidad de wei enviada no coincide con el valor del ticket'
    );

    tickets[nextId] = Ticket({
      owner: msg.sender,
      variant: currentType,
      isUsed: false
    });

    ticketOwners[msg.sender].push(nextId);

    emit PurchasedTicket(msg.sender, msg.value, nextId);
    nextId++;
  }

  function awardPrize(
    address payable _winner,
    uint256 _totalPrizeAmount
  ) public onlyAuthorizedGames {
    require(_winner != address(0), 'Direccion del ganador invalida.');
    require(
      address(this).balance >= _totalPrizeAmount,
      'Fondos insuficientes en el Manager.'
    );

    // SEGURIDAD CRÍTICA: Verificar que el premio no exceda el crédito acumulado.
    require(
      totalValueConsumed[msg.sender] >= _totalPrizeAmount,
      'Cantidad de premio excede el valor de los tickets consumidos por este juego.'
    );

    // Descontar el premio pagado del saldo de valor consumido del juego.
    totalValueConsumed[msg.sender] -= _totalPrizeAmount;

    uint256 feeAmount = (_totalPrizeAmount * platformFeeBasisPoints) / 10000;
    uint256 netPrize = _totalPrizeAmount - feeAmount;

    (bool feeSuccess, ) = payable(contractOwner).call{value: feeAmount}('');
    require(feeSuccess, 'Error al enviar la comision (fee) al owner.');

    (bool prizeSuccess, ) = _winner.call{value: netPrize}('');
    require(prizeSuccess, 'Error al enviar el premio neto al ganador.');

    emit PrizeAwarded(_winner, netPrize, feeAmount);
  }

  function unmarkTicketAsUsed(uint256 _ticketId) public onlyAuthorizedGames {
    require(tickets[_ticketId].owner != address(0), 'Error: Ticket no existe.');
    require(
      tickets[_ticketId].isUsed,
      'Error: El ticket ya esta marcado como no usado.'
    );

    Ticket memory t = tickets[_ticketId];
    Variant memory v = variants[t.variant];

    tickets[_ticketId].isUsed = false;

    // Si se revierte el ticket, el valor consumido debe revertirse también.
    // Esto previene un potencial doble gasto.
    totalValueConsumed[msg.sender] -= v.ticketPrice;

    emit TicketStatusReverted(_ticketId, tickets[_ticketId].owner, msg.sender);
  }

  // =================================================================
  // 8. FUNCIONES DE VISTA (View)
  // =================================================================

  function myTickets() external view returns (uint256[] memory) {
    return ticketOwners[msg.sender];
  }

  // 2. Para consultar los tickets de cualquier otra dirección
  function ticketsOf(address _owner) external view returns (uint256[] memory) {
    require(_owner != address(0), 'Direccion no valida.');
    return ticketOwners[_owner];
  }

  function getAllTicketVariants() external view returns (Variant[] memory) {
    uint256 numTicketTypes = uint256(TicketType.Professional) + 1;
    Variant[] memory allVariants = new Variant[](numTicketTypes);

    for (uint256 i = 0; i < numTicketTypes; i++) {
      TicketType currentType = TicketType(i);
      allVariants[i] = variants[currentType];
    }
    return allVariants;
  }

  function getVariantDetails(
    TicketType _ticketType
  ) external view returns (Variant memory) {
    Variant memory result = variants[_ticketType];

    // Si la variante no fue configurada, ticketPrice será 0. Revertir con mensaje claro.
    require(
      result.ticketPrice > 0,
      'Variant::getVariantDetails: La variante de ticket no ha sido configurada.'
    );

    return result;
  }

  function getTicketDetails(
    uint256 _ticketId
  )
    external
    view
    returns (
      address owner,
      TicketType variantType,
      string memory ticketColor,
      bool isUsed
    )
  {
    Ticket memory requestedTicket = tickets[_ticketId];

    require(
      requestedTicket.owner != address(0),
      'Error: Ticket no existe o ID invalido.'
    );
    Variant memory ticketVariant = variants[requestedTicket.variant];
    return (
      requestedTicket.owner,
      requestedTicket.variant,
      ticketVariant.ticketColor,
      requestedTicket.isUsed
    );
  }

  function markTicketsAsUsedBatch(
    uint256[] calldata _ticketIds
  ) external onlyAuthorizedGames {
    uint256 batchTotalValue = 0;
    uint256 length = _ticketIds.length;

    for (uint256 i = 0; i < length; i++) {
      uint256 tId = _ticketIds[i];
      Ticket storage t = tickets[tId];

      if (tickets[tId].owner != address(0) && !tickets[tId].isUsed) {
        tickets[tId].isUsed = true;

        batchTotalValue += variants[t.variant].ticketPrice;
        emit TicketConsumed(tId, t.owner, msg.sender);
      }
    }

    totalValueConsumed[msg.sender] += batchTotalValue;
  }

  function validTicketsBatch(
    uint256[] calldata _ticketIds
  ) external view returns (bool[] memory) {
    uint256 length = _ticketIds.length;
    bool[] memory results = new bool[](length);

    for (uint256 i = 0; i < length; i++) {
      uint256 tId = _ticketIds[i];

      if (tickets[tId].owner != address(0) && !tickets[tId].isUsed) {
        results[i] = true;
      } else {
        results[i] = false;
      }
    }

    return results;
  }
}
