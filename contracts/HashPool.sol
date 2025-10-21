// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.28;

// =================================================================
// 1. ESTRUCTURAS DE UTILIDAD (Enums, Libraries, Interfaces)
// =================================================================

enum TicketType {
  Novice,
  NoviceII,
  Advanced,
  Expert,
  Professional
}

enum PoolState {
  RegistrationOpen,
  ValidatingEntries,
  RegistrationClosed,
  CalculatingWinner,
  AwardingPrizes,
  GameEnded
}

library TicketManagerStructs {
  struct Variant {
    TicketType ticketType;
    string ticketName;
    uint ticketPrice;
    string ticketColor;
  }
}

interface ITicketManager {
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
    );

  function markTicketAsUsed(uint256 _ticketId) external;

  function unmarkTicketAsUsed(uint256 _ticketId) external;

  function awardPrize(
    address payable _winner,
    uint256 _totalPrizeAmount
  ) external;

  function ticketsPerAddress(
    address _owner
  ) external view returns (uint[] memory);

  function getVariantDetails(
    TicketType _ticketType
  ) external view returns (TicketManagerStructs.Variant memory);
}

// =================================================================
// 2. DECLARACIÓN DEL CONTRATO
// =================================================================

contract HashPool {
  // =================================================================
  // 3. VARIABLES DE ESTADO (Globales y Mapeos)
  // =================================================================

  // Direcciones
  ITicketManager public ticketManager;
  address public owner;
  address public admin; // Admin de la ronda actual

  // Parámetros de la Ronda Actual (NO mapeados, se sobreecriben por ronda)
  TicketType public requiredTicket;
  uint256 startTime;
  uint256 findWinnerTime;
  uint public currentPoolId = 0; // ID de la ronda actual (0 = no hay ronda activa)

  // Mapeos por ID de Ronda (Aislamiento de Datos)
  mapping(uint => address) public poolWinner;
  mapping(uint => PoolState) public poolStatus;
  mapping(uint => bytes32) public poolCombinedHash;
  mapping(uint => uint16) public poolMaxContestants;
  mapping(uint => uint16) public poolContestantCounter;
  mapping(uint => uint16) public poolPreRegistrationCounter;

  // Mapeos anidados
  mapping(uint => mapping(uint16 => address)) public contestants;
  mapping(uint => mapping(address => uint256)) public participantTicket;
  mapping(uint => mapping(address => bytes32)) public contestantSigns;

  // =================================================================
  // 4. EVENTOS
  // =================================================================

  event PoolStatusChanged(uint indexed poolId, PoolState previousStatus, PoolState newStatus);
  event TicketRefunded(uint indexed poolId, address indexed participant, uint256 ticketId);
  event PreRegistrationEvent(uint indexed poolId, address indexed participant, uint256 ticketId);
  event SuccessfulRegistration(uint indexed poolId, address indexed participant, uint256 ticketId);
  event FailedRegistration(
    uint indexed poolId,
    address indexed participant,
    uint256 ticketId,
    string reason
  );

  // =================================================================
  // 5. MODIFICADORES
  // =================================================================

  modifier onlyOwner() {
    require(msg.sender == owner, 'Solo el propietario es el gestor.');
    _;
  }

  modifier onlyAdmin() {
    require(msg.sender == admin, 'Solo el administrador puede ejecutar.');
    _;
  }
  
  modifier onlyActivePool() {
      require(currentPoolId > 0, "No hay pool activo.");
      _;
  }

  // =================================================================
  // 6. CONSTRUCTOR
  // =================================================================

  constructor(
    address _ticketManagerAddress
  ) {
    owner = msg.sender;
    ticketManager = ITicketManager(_ticketManagerAddress);
  }

  // =================================================================
  // 7. FUNCIONES MUTABLES (Lógica de Juego)
  // =================================================================


  function startNewPool(
    uint16 _maxContestants,
    TicketType _requiredTicket,
    uint256 _findWinnerTime,
    address _adminAddress
  ) public onlyOwner {
    // Requerir que el pool anterior haya terminado antes de comenzar uno nuevo.
    require(
        currentPoolId == 0 || poolStatus[currentPoolId] == PoolState.GameEnded,
        "Pool anterior aun no ha terminado (GameEnded)."
    );
    
    // Incrementar el ID para la NUEVA ronda
    currentPoolId++;

    // Establecer parámetros y administrador para la NUEVA ronda
    poolMaxContestants[currentPoolId] = _maxContestants;
    requiredTicket = _requiredTicket;
    findWinnerTime = _findWinnerTime;
    startTime = block.timestamp;
    admin = _adminAddress; // Permite al owner asignar un admin diferente
    
    // El contador y el hash se inicializan a 0 por el nuevo ID.
    setPoolStatus(PoolState.RegistrationOpen);
  }
  

  function setPoolStatus(PoolState newStatus) internal onlyActivePool {
    PoolState previousStatus = poolStatus[currentPoolId];
    poolStatus[currentPoolId] = newStatus;
    emit PoolStatusChanged(currentPoolId, previousStatus, newStatus);
  }

  function PreRegistration(uint ticketId) public onlyActivePool {
    require(poolStatus[currentPoolId] == PoolState.RegistrationOpen, 'Registro terminado');
    require(poolPreRegistrationCounter[currentPoolId] < poolMaxContestants[currentPoolId], 'Cupo maximo alcanzado.');

    poolPreRegistrationCounter[currentPoolId]++;

    emit PreRegistrationEvent(currentPoolId, msg.sender, ticketId);

    if (poolPreRegistrationCounter[currentPoolId] == poolMaxContestants[currentPoolId]) {
      setPoolStatus(PoolState.ValidatingEntries);
    }
  }

  /**
   * @notice Registra un lote de participantes, sus tickets y sus firmas de entropía.
   */
  function registerBatch(
    address[] calldata _participants,
    uint256[] calldata _ticketIds,
    bytes32[] calldata _contestantSigns
  ) public onlyAdmin onlyActivePool {
    require(poolStatus[currentPoolId] == PoolState.ValidatingEntries, 'Registro terminado');
    require(_participants.length > 0, 'Batch vacio.');
    require(
      _participants.length == _ticketIds.length &&
        _ticketIds.length == _contestantSigns.length,
      'Arrays deben tener la misma longitud.'
    );

    uint256 batchSize = _participants.length;
    uint16 currentCounter = poolContestantCounter[currentPoolId];

    require(
      currentCounter + batchSize <= poolMaxContestants[currentPoolId],
      'El batch excede el cupo maximo.'
    );

    bytes32 currentCombinedHash = poolCombinedHash[currentPoolId];

    for (uint16 i = 0; i < batchSize; i++) {
      contestants[currentPoolId][currentCounter] = _participants[i];
      participantTicket[currentPoolId][_participants[i]] = _ticketIds[i];
      contestantSigns[currentPoolId][_participants[i]] = _contestantSigns[i];
      // ticketManager.markTicketAsUsed(_ticketIds[i]);
      currentCombinedHash = keccak256(
        abi.encodePacked(currentCombinedHash, _contestantSigns[i])
      );

      emit SuccessfulRegistration(currentPoolId, _participants[i], _ticketIds[i]);
      currentCounter++;
    }

    poolCombinedHash[currentPoolId] = currentCombinedHash;
    poolContestantCounter[currentPoolId] = currentCounter;

    if (currentCounter >= poolMaxContestants[currentPoolId]) {
      setPoolStatus(PoolState.RegistrationClosed);
    } else {
      poolPreRegistrationCounter[currentPoolId] = currentCounter;
      setPoolStatus(PoolState.RegistrationOpen);
    }
  }

  function selectWinner() public onlyAdmin onlyActivePool {
    uint16 currentContestants = poolContestantCounter[currentPoolId];
    
    require(
      poolStatus[currentPoolId] == PoolState.RegistrationClosed ||
        (block.timestamp >= findWinnerTime &&
          poolStatus[currentPoolId] == PoolState.RegistrationOpen),
      'El registro aun no cierra o no ha pasado el tiempo.'
    );

    if (currentContestants == 0) {
      setPoolStatus(PoolState.GameEnded);
      return;
    }

    if (poolStatus[currentPoolId] == PoolState.RegistrationOpen) {
      setPoolStatus(PoolState.RegistrationClosed);
    }

    uint256 randomNumberSeed = uint256(poolCombinedHash[currentPoolId]);

    uint256 winningIndex = randomNumberSeed % uint256(currentContestants);

    poolWinner[currentPoolId] = contestants[currentPoolId][uint16(winningIndex)];

    setPoolStatus(PoolState.AwardingPrizes);
  }

  function awaringWinner() public onlyAdmin onlyActivePool {
    require(
      poolStatus[currentPoolId] == PoolState.AwardingPrizes,
      'El ganador ya fue premiado o no esta en fase de premiacion.'
    );

    address payable winnerAddress = payable(poolWinner[currentPoolId]);
    require(winnerAddress != address(0), 'El ganador no esta establecido.');

    uint256 totalPrize = _calculatePrizePool(currentPoolId);

    ticketManager.awardPrize(winnerAddress, totalPrize);

    setPoolStatus(PoolState.GameEnded);
  }

  function failRegistration(
    address _participant,
    uint ticketId,
    string calldata reason
  ) public onlyAdmin onlyActivePool {
    require(poolStatus[currentPoolId] == PoolState.ValidatingEntries, 'Registro terminado');
    require(
      participantTicket[currentPoolId][_participant] == 0,
      'Participante ya registrado.'
    );
    emit FailedRegistration(currentPoolId, _participant, ticketId, reason);
  }

  /**
   * @notice Permite al participante solicitar la devolución de su ticket si el pool terminó SIN ganador.
   * El participante debe especificar de qué ronda es su ticket.
   */
  function requestRefund(uint _poolId) public {
    require(_poolId > 0 && _poolId < currentPoolId, 'ID de pool no valido o activo.');
    
    // Se requiere que la ronda haya terminado
    require(poolStatus[_poolId] == PoolState.GameEnded, 'El pool aun no termina.');
    // Se requiere que NO haya habido ganador para esa ronda
    require(poolWinner[_poolId] == address(0), 'El ganador ya fue seleccionado y premiado.');

    uint256 ticketId = participantTicket[_poolId][msg.sender];
    require(ticketId != 0, 'No estas registrado en este pool.');

    // Borrar la entrada de ticket para el participante en esa ronda
    delete participantTicket[_poolId][msg.sender];

    ticketManager.unmarkTicketAsUsed(ticketId);

    emit TicketRefunded(_poolId, msg.sender, ticketId);
  }

  // =================================================================
  // 8. FUNCIONES DE VISTA (View y Pure)
  // =================================================================

  function _getRequiredTicketPrice() internal view returns (uint) {
    TicketManagerStructs.Variant memory variant = ticketManager
      .getVariantDetails(requiredTicket);
    return variant.ticketPrice;
  }

  function _calculatePrizePool(uint _poolId) internal view returns (uint256 totalPrize) {
    uint256 singleTicketPrice = _getRequiredTicketPrice();
    // Usa el contador de la ronda específica para calcular el premio
    totalPrize = singleTicketPrice * uint256(poolContestantCounter[_poolId]);
  }

  function getCurrentPoolStatus() external view returns (PoolState) {
    return poolStatus[currentPoolId];
  }
  
  function getPoolStatusById(uint _poolId) external view returns (PoolState) {
    return poolStatus[_poolId];
  }
  
  function getPoolWinnerById(uint _poolId) external view returns (address) {
    return poolWinner[_poolId];
  }


  function getCurrentPoolInfo()
    external
    view
    onlyActivePool
    returns (
      TicketType requiredTicketType,
      uint16 maxContestantsCount,
      uint16 currentContestants,
      uint256 winnerSelectionTime
    )
  {
    return (
      requiredTicket,
      poolMaxContestants[currentPoolId],
      poolContestantCounter[currentPoolId],
      findWinnerTime
    );
  }

  function getMyCurrentTicketId(address _participant) external view returns (uint256) {
    return participantTicket[currentPoolId][_participant];
  }

  function getMyTicketId(uint _poolId) external view returns (uint256) {
    return participantTicket[_poolId][msg.sender];
  }

  function getCurrentContestantsAddress() external view returns (address[] memory) {
    uint16 count = poolContestantCounter[currentPoolId];
    address[] memory participants = new address[](uint256(count));

    for (uint i = 0; i < count; i++) {
      participants[i] = contestants[currentPoolId][uint16(i)];
    }

    return participants;
  }

  function getContestantAddressByPoolId(uint _poolId) external view returns (address[] memory) {
    uint16 count = poolContestantCounter[_poolId];
    address[] memory participants = new address[](uint256(count));

    for (uint i = 0; i < count; i++) {
      participants[i] = contestants[_poolId][uint16(i)];
    }

    return participants;
  }
}