import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";


const TICKET_COLORS_AND_VALUES = [
    { color: '#3498DB', value: 1.00, name: 'Ticket Novato' },
    { color: '#2ECC71', value: 5.00, name: 'Ticket Novato II' },
    { color: '#F1C40F', value: 10.00, name: 'Ticket Avanzado' },
    { color: '#E74C3C', value: 25.00, name: 'Ticket Experto' },
    { color: '#9B59B6', value: 50.00, name: 'Ticket Profesional' },
];

const TicketModule = buildModule(
    'TicketModule',
    (m) => {
        const ticketNames = TICKET_COLORS_AND_VALUES.map(ticket => ticket.name);

        const ticketColors = TICKET_COLORS_AND_VALUES.map(ticket => ticket.color);

        const ticketPrices = TICKET_COLORS_AND_VALUES.map(ticket => {
            return BigInt(Math.floor(ticket.value * 10**18));
        });

        const ticket = m.contract('TicketManager', [ticketNames, ticketPrices, ticketColors]);

        return { ticket };
    }
);

export default TicketModule;