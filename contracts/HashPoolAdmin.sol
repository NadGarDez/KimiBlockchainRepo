// SPDX-License-Identifier: UNLICENSED  

pragma solidity ^0.8.28;

import {HashPool, TicketType} from './HashPool.sol';

// =================================================================
// 1. INTERFACES
// =================================================================

interface ITicketManager {
    function authorizePool(address _poolAddress) external;
}


// =================================================================
// 2. DECLARACIÓN DEL CONTRATO (FACTORÍA)
// =================================================================

contract HassPoolAdmin {
    // La dirección del dueño del contrato de la Factoría
    address public contractOwner; 

    address[] public deployedPools; 

    mapping(uint256 => HashPool) public pools;

    // Dirección del contrato TicketManager (proveedor de liquidez y validación)
    address public ticketManagerAddress;

    event PoolCreated(
        uint256 indexed poolId, 
        address indexed poolAddress, 
        address indexed creator,
        uint16 maxContestants
    );

    // =================================================================
    // 3. CONSTRUCTOR
    // =================================================================

    constructor(address _ticketManagerAddress) {
        contractOwner = msg.sender;
        ticketManagerAddress = _ticketManagerAddress;
    }

    // =================================================================
    // 4. MODIFICADORES
    // =================================================================

    modifier onlyOwner() {
        require(msg.sender == contractOwner, "Solo el propietario es el gestor de la Factoria.");
        _;
    }

    // =================================================================
    // 5. FUNCIONES MUTABLES
    // =================================================================

    /**
     * @notice Despliega un nuevo contrato HashPool con sus parámetros iniciales.
     * PASO CRÍTICO: Autoriza al nuevo Pool en el TicketManager inmediatamente.
     * @param _maxContestants El número máximo de participantes.
     * @param _requiredTicket El tipo de ticket requerido.
     * @param _findWinnerTime El timestamp en el que el pool puede cerrarse por tiempo.
     * @return newPoolAddress La dirección del nuevo contrato HashPool.
     */
    function createNewPool(
        uint16 _maxContestants, 
        TicketType _requiredTicket,
        uint256 _findWinnerTime
    ) public onlyOwner returns (address newPoolAddress) {
        
        // 1. Despliegue del HashPool
        HashPool newPool = new HashPool(
            _maxContestants,
            _requiredTicket,
            _findWinnerTime,
            ticketManagerAddress,
            msg.sender
        );

        newPoolAddress = address(newPool);
        
        ITicketManager(ticketManagerAddress).authorizePool(newPoolAddress); 

        deployedPools.push(newPoolAddress);
        
        uint256 poolId = deployedPools.length - 1;
        pools[poolId] = newPool;

        // 4. Evento
        emit PoolCreated(
            poolId, 
            newPoolAddress, 
            msg.sender, 
            _maxContestants
        );
    }

    // =================================================================
    // 6. FUNCIONES DE VISTA
    // =================================================================

    function getPoolCount() public view returns (uint256) {
        return deployedPools.length;
    }

    function getPoolAddress(uint256 _poolId) public view returns (address) {
        require(_poolId < deployedPools.length, "ID de Pool no valido.");
        return deployedPools[_poolId];
    }
}