import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const TICKET_LIMIT = 20;
const TICKET_PRICE = 5;


const TicketModule = buildModule(
    'TicketModule',
    (m) => {
        const ticketLimit = m.getParameter(
            'constructorTicketLimit',
            TICKET_LIMIT
        );

        const ticketPrice = m.getParameter(
            'constructorTicketPrice',
            TICKET_PRICE
        );

        const ticket = m.contract('Ticket', [ticketLimit, ticketPrice]);

        return { ticket}

    }
);

export default TicketModule;