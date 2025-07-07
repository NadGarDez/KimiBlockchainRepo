// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.28;

contract Ticket {

    uint public ticketLimit;
    uint public ticketPrice;
    address payable public contractOwner;

    struct ticket {
        address owner;
        uint paidValue;
    }

    uint nextId = 0;


    mapping (uint => ticket) tickets;
    mapping (address => uint256[]) ticketOwners;

    event PurchasedTicket(address owner, uint value);
    event WithdrawnToOwner(address owner, uint value);

    constructor (uint constructorTicketLimit, uint constructorTicketPrice ) {
        contractOwner =  payable(msg.sender);
        ticketLimit = constructorTicketLimit;
        ticketPrice = constructorTicketPrice;
    }

    function buy() public payable {
        require(
            ticketLimit > 0,
            'No hay tickets disponibles'
        );

         require(
            msg.value == ticketPrice,
            'La cantidad de wei enviada no coincide con el valor del ticket'
        );

        tickets[nextId] = ticket({
            owner: msg.sender,
            paidValue: msg.value
        });

        ticketOwners[msg.sender].push(nextId); 

        emit PurchasedTicket(msg.sender, msg.value);
        nextId++;
        ticketLimit--;
    }

    function withdrawOwner() public {
        require(msg.sender == contractOwner, 'No eres el propietario del contrato');
        require(address(this).balance > 100, 'La disponibilidad de fondos es inferior a la requerida para hacer retiros');
        contractOwner.transfer(address(this).balance);
        emit WithdrawnToOwner(contractOwner, address(this).balance);
    }


    function ticketAmoutPerAddress() public view returns (uint)  {
        return ticketOwners[msg.sender].length;
    }
}