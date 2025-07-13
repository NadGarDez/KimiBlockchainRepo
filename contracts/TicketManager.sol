// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.28;

contract TicketManager {
  address payable public contractOwner;

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
  }

  uint nextId = 1;

  mapping(uint => Ticket) tickets;
  mapping(address => uint256[]) ticketOwners;
  mapping(TicketType => Variant) variants;
  mapping(string => TicketType) public stringToTicketType;

  event PurchasedTicket(address owner, uint value);
  event WithdrawnToOwner(address owner, uint value);
  mapping(string => bool) public isNameValid;

  constructor(
    string[] memory _ticketNames,
    uint[] memory _ticketPrices,
    string[] memory _ticketColorsForVariants
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
        variant: currentType
    });

    ticketOwners[msg.sender].push(nextId);

    emit PurchasedTicket(msg.sender, msg.value);
    nextId++;
  }

  function withdrawOwner() public {
    require(msg.sender == contractOwner, 'No eres el propietario del contrato');
    require(
      address(this).balance > 100,
      'La disponibilidad de fondos es inferior a la requerida para hacer retiros'
    );
    contractOwner.transfer(address(this).balance);
    emit WithdrawnToOwner(contractOwner, address(this).balance);
  }

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
  ) public view returns (address owner, TicketType variantType, string memory ticketColor) {
    Ticket memory requestedTicket = tickets[_ticketId];

    require(
      requestedTicket.owner != address(0),
      'Error: Ticket no existe o ID invalido.'
    );
    Variant memory ticketVariant = variants[requestedTicket.variant];
    return (requestedTicket.owner, requestedTicket.variant, ticketVariant.ticketColor);
  }
}