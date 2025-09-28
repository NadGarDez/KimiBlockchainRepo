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
address public poolFactoryAddress; 
mapping(address => bool) public authorizedPools; 
uint256 public platformFeeBasisPoints;
uint256 nextId = 1;

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
event TicketConsumed(uint256 ticketId, address user, address consumingContract);
event TicketStatusReverted(
  uint256 ticketId,
  address user,
  address consumingContract
); 
event PrizeAwarded(address indexed winner, uint256 netPrize, uint256 feeAmount);
event PoolFactorySet(address oldAddress, address newAddress);
event PoolAuthorized(address indexed poolAddress, address indexed factory);


// =================================================================
// 5. MODIFICADORES
// =================================================================

modifier onlyOwner() {
  require(msg.sender == contractOwner, 'Solo el propietario es el gestor.');
  _;
}

modifier onlyPoolFactory() {
    require(msg.sender == poolFactoryAddress, 'Solo la Factoria de Pools autorizada.');
    _;
}

modifier onlyAuthorizedPool() {
    require(authorizedPools[msg.sender], 'Solo un HashPool autorizado puede llamar.');
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
 * @notice Establece la dirección del contrato Pool Factory. Solo puede ser llamada una vez.
 * Resuelve la dependencia circular en el deploy.
 */
function setPoolFactoryAddress(address _factoryAddress) public onlyOwner {
  require(poolFactoryAddress == address(0), "La Factoria ya esta establecida.");
  require(_factoryAddress != address(0), "Direccion invalida.");
  
  address oldAddress = poolFactoryAddress;
  poolFactoryAddress = _factoryAddress;
  
  emit PoolFactorySet(oldAddress, _factoryAddress);
}

/**
 * @notice Autoriza un nuevo HashPool para interactuar con este Manager. 
 * Solo la Pool Factory puede llamar a esta función.
 */
function authorizePool(address _poolAddress) public onlyPoolFactory {
    require(_poolAddress != address(0), "Direccion del Pool invalida.");
    require(!authorizedPools[_poolAddress], "El Pool ya esta autorizado.");
    
    authorizedPools[_poolAddress] = true;
    
    emit PoolAuthorized(_poolAddress, msg.sender);
}

function depositEmergencyFunds() public payable onlyOwner {
  // Permite al dueño enviar fondos de emergencia al contrato
}

function setPlatformFee(uint256 newFee) public onlyOwner {
  require(newFee <= 1000, 'Fee no puede exceder el 10% (1000 BPS)');
  platformFeeBasisPoints = newFee;
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
) public onlyAuthorizedPool { 
  require(_winner != address(0), 'Direccion del ganador invalida.');
  require(
    address(this).balance >= _totalPrizeAmount,
    'Fondos insuficientes en el Manager.'
  );

  uint256 feeAmount = (_totalPrizeAmount * platformFeeBasisPoints) / 10000;

  uint256 netPrize = _totalPrizeAmount - feeAmount;

  (bool feeSuccess, ) = payable(contractOwner).call{value: feeAmount}('');
  require(feeSuccess, 'Error al enviar la comision (fee) al owner.');

  (bool prizeSuccess, ) = _winner.call{value: netPrize}('');
  require(prizeSuccess, 'Error al enviar el premio neto al ganador.');

  emit PrizeAwarded(_winner, netPrize, feeAmount);
}

function markTicketAsUsed(uint256 _ticketId) public onlyAuthorizedPool { 
  require(tickets[_ticketId].owner != address(0), 'Error: Ticket no existe.');
  require(
    !tickets[_ticketId].isUsed,
    'Error: El ticket ya fue marcado como usado.'
  );

  tickets[_ticketId].isUsed = true;

  emit TicketConsumed(_ticketId, tickets[_ticketId].owner, msg.sender);
}

function unmarkTicketAsUsed(uint256 _ticketId) public onlyAuthorizedPool { 
  require(tickets[_ticketId].owner != address(0), 'Error: Ticket no existe.');
  require(
    tickets[_ticketId].isUsed,
    'Error: El ticket ya esta marcado como no usado.'
  );

  tickets[_ticketId].isUsed = false;

  emit TicketStatusReverted(_ticketId, tickets[_ticketId].owner, msg.sender);
}


// =================================================================
// 8. FUNCIONES DE VISTA (View)
// =================================================================

function ticketsPerAddress() public view returns (uint256[] memory) {
  return ticketOwners[msg.sender];
}

function getAllTicketVariants() public view returns (Variant[] memory) {
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
) public view returns (Variant memory) {
  return variants[_ticketType];
}

function getTicketDetails(
  uint256 _ticketId
)
  public
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
}