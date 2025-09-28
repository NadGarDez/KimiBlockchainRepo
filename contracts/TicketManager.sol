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
  string ticketName;
  uint ticketPrice;
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

address payable public contractOwner;
address public trustedPoolContract; // Dirección del HashPool
uint256 public platformFeeBasisPoints;
uint nextId = 1;

// Mapeos
mapping(uint => Ticket) tickets;
mapping(address => uint256[]) ticketOwners;
mapping(TicketType => Variant) variants;
mapping(string => TicketType) public stringToTicketType;
mapping(string => bool) public isNameValid;


// =================================================================
// 4. EVENTOS
// =================================================================

event FeeAdded(uint amount);
event PurchasedTicket(address owner, uint value, uint ticketId);
event TicketConsumed(uint ticketId, address user, address consumingContract);
event TicketStatusReverted(
  uint ticketId,
  address user,
  address consumingContract
); 
event PrizeAwarded(address indexed winner, uint netPrize, uint feeAmount);
event TrustedPoolSet(address oldAddress, address newAddress); 


// =================================================================
// 5. MODIFICADORES
// =================================================================

modifier onlyOwner() {
  require(msg.sender == contractOwner, 'Solo el propietario es el gestor.');
  _;
}

modifier onlyTrustedPool() {
  require(
    msg.sender == trustedPoolContract,
    'Solo el contrato de Pool de confianza es autorizado.'
  );
  _;
}


// =================================================================
// 6. CONSTRUCTOR
// =================================================================

constructor(
  string[] memory _ticketNames,
  uint[] memory _ticketPrices,
  string[] memory _ticketColorsForVariants,
  uint256 _feePercentage
) {
  uint numTicketTypes = uint(TicketType.Professional) + 1;

  require(
    _ticketNames.length == numTicketTypes &&
      _ticketPrices.length == numTicketTypes &&
      _ticketColorsForVariants.length == numTicketTypes,
    'Error: informacion incompleta para tipos de tickets o colores.'
  );

  for (uint i = 0; i < numTicketTypes; i++) {
    TicketType currentType = TicketType(i);
    stringToTicketType[_ticketNames[i]] = currentType;
    isNameValid[_ticketNames[i]] = true;
    variants[currentType] = Variant(
      currentType,
      _ticketNames[i],
      _ticketPrices[i],
      _ticketColorsForVariants[i]
    );
  }

  contractOwner = payable(msg.sender);
  platformFeeBasisPoints = _feePercentage;
}


// =================================================================
// 7. FUNCIONES MUTABLES (SETTERS, Transacciones, Lógica)
// =================================================================

function setTrustedPoolContract(address _newTrustedPoolAddress) public onlyOwner {
  require(_newTrustedPoolAddress != address(0), 'Direccion invalida.');
  
  address oldAddress = trustedPoolContract;
  trustedPoolContract = _newTrustedPoolAddress;
  
  emit TrustedPoolSet(oldAddress, _newTrustedPoolAddress);
}

function depositEmergencyFunds() public payable onlyOwner {
  // Permite al dueño enviar fondos de emergencia al contrato
}

function setPlatformFee(uint256 newFee) public onlyOwner {
  require(newFee <= 1000, 'Fee no puede exceder el 10% (1000 BPS)');
  platformFeeBasisPoints = newFee;
}

function buy(string memory ticketName) public payable {
  require(
    isNameValid[ticketName],
    'Error: La variante de ticket proporcionada no existe en este contrato.'
  );

  TicketType currentType = stringToTicketType[ticketName];

  Variant memory requestedVariant = variants[currentType];

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
) public onlyTrustedPool {
  require(_winner != address(0), 'Direccion del ganador invalida.');
  require(
    address(this).balance >= _totalPrizeAmount,
    'Fondos insuficientes en el Manager.'
  );

  uint256 feeAmount = (_totalPrizeAmount * platformFeeBasisPoints) / 10000;

  uint256 netPrize = _totalPrizeAmount - feeAmount;

  (bool feeSuccess, ) = contractOwner.call{value: feeAmount}('');
  require(feeSuccess, 'Error al enviar la comision (fee) al owner.');

  (bool prizeSuccess, ) = _winner.call{value: netPrize}('');
  require(prizeSuccess, 'Error al enviar el premio neto al ganador.');

  emit PrizeAwarded(_winner, netPrize, feeAmount);
}

function markTicketAsUsed(uint256 _ticketId) public onlyTrustedPool {
  require(tickets[_ticketId].owner != address(0), 'Error: Ticket no existe.');
  require(
    !tickets[_ticketId].isUsed,
    'Error: El ticket ya fue marcado como usado.'
  );

  tickets[_ticketId].isUsed = true;

  emit TicketConsumed(_ticketId, tickets[_ticketId].owner, msg.sender);
}

function unmarkTicketAsUsed(uint256 _ticketId) public onlyTrustedPool {
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

function ticketAmoutPerAddress() public view returns (uint) {
  return ticketOwners[msg.sender].length;
}

function ticketsPerAddress() public view returns (uint[] memory) {
  return ticketOwners[msg.sender];
}

function getAllTicketVariants() public view returns (Variant[] memory) {
  uint numTicketTypes = uint(TicketType.Professional) + 1;
  Variant[] memory allVariants = new Variant[](numTicketTypes);

  for (uint i = 0; i < numTicketTypes; i++) {
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