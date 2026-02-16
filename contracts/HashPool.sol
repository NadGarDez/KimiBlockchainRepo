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
    uint256 ticketPrice;
    string ticketName;
    string ticketColor;
  }
}

// ESTRUCTURA ÚNICA DE RETORNO (PoolDetails)
// Resuelve el problema de "Stack too deep" al agrupar múltiples valores de retorno.
struct PoolDetails {
  uint poolId;
  PoolState currentStatus;
  address poolManagerAddress;
  uint256 startTimeStamp;
  uint256 winnerSelectionTime;
  TicketType requiredTicketType;
  uint256 requiredTicketValue;
  string ticketName;
  string ticketColor;
  uint16 maxContestantsCount;
  uint16 currentContestants;
  uint16 preRegistrationCount;
  uint256 participantTicketId; // Cero si no está participando
  address poolWinnerAddress;
  uint256 totalPrizePool;
  address[] confirmedContestants;
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

  function markTicketsAsUsedBatch(
    uint256[] calldata _ticketIds
  ) external returns (uint256[] memory validTicketsIndex);

  function unmarkTicketAsUsed(uint256 _ticketId) external;

  /**
   * @dev Prototipo actualizado para la interfaz (interface) o contrato padre.
   * @param _winner Dirección que recibe el premio neto.
   * @param _totalPrizeAmount Monto total (antes de comisiones).
   * @param _gameId ID único de la partida/sesión de juego.
   * @param _gameName Nombre descriptivo del juego.
   */
  function awardPrize(
    address payable _winner,
    uint256 _totalPrizeAmount,
    uint256 _gameId,
    string calldata _gameName
  ) external;

  function ticketsPerAddress(
    address _owner
  ) external view returns (uint256[] memory);

  function getVariantDetails(
    TicketType _ticketType
  ) external view returns (TicketManagerStructs.Variant memory);
}

// =================================================================
// 2. DECLARACIÓN DEL CONTRATO
// =================================================================

contract HashPool {
  // =================================================================
  // 3. VARIABLES DE ESTADO
  // =================================================================

  ITicketManager public ticketManager;
  address public owner;
  uint public currentPoolId = 0;

  mapping(uint => address) public poolWinner;
  mapping(uint => PoolState) public poolStatus;
  mapping(uint => bytes32) public poolCombinedHash;
  mapping(uint => uint16) public poolMaxContestants;
  mapping(uint => uint16) public poolContestantCounter;
  mapping(uint => uint16) public poolPreRegistrationCounter;

  mapping(uint => TicketType) public poolRequiredTicket;
  mapping(uint => uint256) public poolRequiredTicketPrice;
  mapping(uint => uint256) public poolStartTime;
  mapping(uint => uint256) public poolFindWinnerTime;

  mapping(uint => mapping(uint16 => address)) public contestants;
  mapping(uint => mapping(address => uint256)) public participantTicket;
  mapping(uint => mapping(address => bytes32)) public contestantSigns;

  // =================================================================
  // 4. EVENTOS
  // =================================================================

  event PoolStatusChanged(
    uint indexed poolId,
    PoolState previousStatus,
    PoolState newStatus
  );
  event TicketRefunded(
    uint indexed poolId,
    address indexed participant,
    uint256 ticketId
  );
  event PreRegistrationEvent(
    uint indexed poolId,
    address indexed participant,
    uint256 ticketId,
    bytes32 contestantSign
  );
  event SuccessfulRegistration(
    uint indexed poolId,
    address indexed participant,
    uint256 ticketId
  );
  event FailedRegistration(
    uint indexed poolId,
    address indexed participant,
    uint256 ticketId,
    string reason
  );

  event startinANewPool(
    uint indexed poolId,
    TicketType requiredTicket,
    uint256 findWinnerTime
  );

  // =================================================================
  // 5. MODIFICADORES
  // =================================================================

  modifier onlyOwner() {
    require(msg.sender == owner, 'Solo el propietario es el gestor.');
    _;
  }

  modifier onlyActivePool() {
    require(currentPoolId > 0, 'No hay pool activo.');
    _;
  }

  // =================================================================
  // 6. CONSTRUCTOR
  // =================================================================

  constructor(address _ticketManagerAddress) {
    owner = msg.sender;
    ticketManager = ITicketManager(_ticketManagerAddress);
  }

  // =================================================================
  // 7. FUNCIONES MUTABLES
  // =================================================================

  function startNewPool(
    uint16 _maxContestants,
    TicketType _requiredTicket,
    uint256 _findWinnerTime
  ) public onlyOwner {
    emit startinANewPool(currentPoolId + 1, _requiredTicket, _findWinnerTime);

    require(
      currentPoolId == 0 || poolStatus[currentPoolId] == PoolState.GameEnded,
      'Pool anterior aun no ha terminado (GameEnded).'
    );

    currentPoolId++;

    poolMaxContestants[currentPoolId] = _maxContestants;
    poolRequiredTicket[currentPoolId] = _requiredTicket;
    poolFindWinnerTime[currentPoolId] = _findWinnerTime;
    poolStartTime[currentPoolId] = block.timestamp;

    TicketManagerStructs.Variant memory variant = ticketManager
      .getVariantDetails(_requiredTicket);

    require(
      variant.ticketType == _requiredTicket,
      'Pool: Tipo de ticket requerido invalido.'
    );

    poolRequiredTicketPrice[currentPoolId] = variant.ticketPrice;

    setPoolStatus(PoolState.RegistrationOpen);
  }

  function setPoolStatus(PoolState newStatus) internal onlyActivePool {
    PoolState previousStatus = poolStatus[currentPoolId];
    poolStatus[currentPoolId] = newStatus;
    emit PoolStatusChanged(currentPoolId, previousStatus, newStatus);
  }

  function PreRegistration(
    uint ticketId,
    bytes32 contestantSign
  ) public onlyActivePool {
    require(
      poolStatus[currentPoolId] == PoolState.RegistrationOpen,
      'Registro terminado'
    );
    require(
      poolPreRegistrationCounter[currentPoolId] <
        poolMaxContestants[currentPoolId],
      'Cupo maximo alcanzado.'
    );

    poolPreRegistrationCounter[currentPoolId]++;

    emit PreRegistrationEvent(
      currentPoolId,
      msg.sender,
      ticketId,
      contestantSign
    );

    if (
      poolPreRegistrationCounter[currentPoolId] ==
      poolMaxContestants[currentPoolId]
    ) {
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
  ) public onlyOwner onlyActivePool {
    require(
      poolStatus[currentPoolId] == PoolState.ValidatingEntries,
      'Registro terminado'
    );
    require(_participants.length > 0, 'Batch vacio.');
    require(
      _participants.length == _ticketIds.length &&
        _ticketIds.length == _contestantSigns.length,
      'Arrays deben tener la misma longitud.'
    );

    uint256 batchSize = _participants.length;
    uint256 currentCounter = poolContestantCounter[currentPoolId]; // Cambiar a uint256

    require(
      currentCounter + batchSize <= poolMaxContestants[currentPoolId],
      'El batch excede el cupo maximo.'
    );

    bytes32 currentCombinedHash = poolCombinedHash[currentPoolId];

    // LLAMAR ANTES DE MODIFICAR ESTADO PROPIO
    uint256[] memory validTicketIndex = ticketManager.markTicketsAsUsedBatch(
      _ticketIds
    );

    uint256 successfulRegistrations = 0;

    for (uint256 i = 0; i < batchSize; i++) {
      // Cambiar a uint256
      if (validTicketIndex[i] == 0) {
        emit FailedRegistration(
          currentPoolId,
          _participants[i],
          _ticketIds[i],
          'Ticket invalido o ya usado.'
        );
        continue;
      }

      contestants[currentPoolId][uint16(currentCounter)] = _participants[i];
      participantTicket[currentPoolId][_participants[i]] = _ticketIds[i];
      // ¿Realmente necesitas almacenar esto? Si solo es para el hash, elimínalo
      // contestantSigns[currentPoolId][_participants[i]] = _contestantSigns[i];

      currentCombinedHash = keccak256(
        abi.encodePacked(currentCombinedHash, _contestantSigns[i])
      );

      emit SuccessfulRegistration(
        currentPoolId,
        _participants[i],
        _ticketIds[i]
      );
      currentCounter++;
      successfulRegistrations++;
    }

    // Solo actualizar si hubo registros exitosos
    if (successfulRegistrations > 0) {
      poolCombinedHash[currentPoolId] = currentCombinedHash;
      poolContestantCounter[currentPoolId] = uint16(currentCounter);

      if (currentCounter >= poolMaxContestants[currentPoolId]) {
        setPoolStatus(PoolState.RegistrationClosed);
      } else {
        poolPreRegistrationCounter[currentPoolId] = uint16(currentCounter);
        setPoolStatus(PoolState.RegistrationOpen);
      }
    }
  }

  function selectWinner() public onlyOwner onlyActivePool {
    uint16 currentContestants = poolContestantCounter[currentPoolId];

    require(
      poolStatus[currentPoolId] == PoolState.RegistrationClosed ||
        (block.timestamp >= poolFindWinnerTime[currentPoolId] &&
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

    poolWinner[currentPoolId] = contestants[currentPoolId][
      uint16(winningIndex)
    ];

    setPoolStatus(PoolState.AwardingPrizes);
  }

  function awaringWinner() public onlyOwner onlyActivePool {
    require(
      poolStatus[currentPoolId] == PoolState.AwardingPrizes,
      'El ganador ya fue premiado o no esta en fase de premiacion.'
    );

    address payable winnerAddress = payable(poolWinner[currentPoolId]);
    require(winnerAddress != address(0), 'El ganador no esta establecido.');

    uint256 totalPrize = _calculatePrizePool(currentPoolId);

    ticketManager.awardPrize(winnerAddress, totalPrize, currentPoolId, 'HashPool');

    setPoolStatus(PoolState.GameEnded);
  }

  function failRegistration(
    address _participant,
    uint ticketId,
    string calldata reason
  ) public onlyOwner onlyActivePool {
    require(
      poolStatus[currentPoolId] == PoolState.ValidatingEntries,
      'Registro terminado'
    );
    require(
      participantTicket[currentPoolId][_participant] == 0,
      'Participante ya registrado.'
    );
    emit FailedRegistration(currentPoolId, _participant, ticketId, reason);
  }

  function requestRefund(uint _poolId) public {
    require(
      _poolId > 0 && _poolId < currentPoolId,
      'ID de pool no valido o activo.'
    );

    require(
      poolStatus[_poolId] == PoolState.GameEnded,
      'El pool aun no termina.'
    );
    require(
      poolWinner[_poolId] == address(0),
      'El ganador ya fue seleccionado y premiado.'
    );

    uint256 ticketId = participantTicket[_poolId][msg.sender];
    require(ticketId != 0, 'No estas registrado en este pool.');

    delete participantTicket[_poolId][msg.sender];

    ticketManager.unmarkTicketAsUsed(ticketId);

    emit TicketRefunded(_poolId, msg.sender, ticketId);
  }

  // =================================================================
  // 8. FUNCIONES DE VISTA
  // =================================================================

  function _calculatePrizePool(
    uint _poolId
  ) internal view returns (uint256 totalPrize) {
    uint256 singleTicketPrice = poolRequiredTicketPrice[_poolId];
    totalPrize = singleTicketPrice * uint256(poolContestantCounter[_poolId]);
    return totalPrize;
  }

  // Función interna separada para el bucle del array dinámico
  function _getConfirmedContestants(
    uint _poolId,
    uint16 _count
  ) internal view returns (address[] memory) {
    address[] memory confirmedContestants = new address[](uint256(_count));
    for (uint i = 0; i < _count; i++) {
      confirmedContestants[i] = contestants[_poolId][uint16(i)];
    }
    return confirmedContestants;
  }

  /**
   * @notice Super vista que devuelve todos los detalles del pool agrupados en un struct.
   * Si _poolId es 0, consulta los datos del pool activo (currentPoolId).
   * Se recomienda usar viaIR: true en el compilador para esta función.
   */
  function getPoolDetails(
    uint _poolId,
    address _participant
  ) external view returns (PoolDetails memory details) {
    uint poolToQuery = _poolId;

    if (poolToQuery == 0) {
      poolToQuery = currentPoolId;
    }

    require(
      poolToQuery > 0 && poolToQuery <= currentPoolId,
      'Pool ID no valido o no activo.'
    );

    // Lecturas minimas necesarias
    TicketType _requiredTicketType = poolRequiredTicket[poolToQuery];
    uint16 _currentContestants = poolContestantCounter[poolToQuery];

    // Ejecutar la lógica pesada del array en una sub-función (libera la pila)
    address[] memory _confirmedContestants = _getConfirmedContestants(
      poolToQuery,
      _currentContestants
    );

    // Obtener los detalles del ticket (esto también crea variables locales)
    TicketManagerStructs.Variant memory variant = ticketManager
      .getVariantDetails(_requiredTicketType);

    // ASIGNACIÓN FINAL AL STRUCT ÚNICO (usando lecturas directas del mapeo)
    details = PoolDetails({
      poolId: poolToQuery,
      currentStatus: poolStatus[poolToQuery],
      poolManagerAddress: owner,
      startTimeStamp: poolStartTime[poolToQuery],
      winnerSelectionTime: poolFindWinnerTime[poolToQuery],
      requiredTicketType: _requiredTicketType,
      requiredTicketValue: poolRequiredTicketPrice[poolToQuery],
      ticketName: variant.ticketName,
      ticketColor: variant.ticketColor,
      maxContestantsCount: poolMaxContestants[poolToQuery],
      currentContestants: _currentContestants,
      preRegistrationCount: poolPreRegistrationCounter[poolToQuery],
      participantTicketId: participantTicket[poolToQuery][_participant],
      poolWinnerAddress: poolWinner[poolToQuery],
      totalPrizePool: _calculatePrizePool(poolToQuery),
      confirmedContestants: _confirmedContestants
    });

    return details;
  }

  function resetCurrentPool() external onlyOwner onlyActivePool {
    // esta funcion se eliminara en produccion
    setPoolStatus(PoolState.GameEnded);

    // Limpiar datos asociados al pool actual
    delete poolCombinedHash[currentPoolId];
    delete poolMaxContestants[currentPoolId];
    delete poolContestantCounter[currentPoolId];
    delete poolPreRegistrationCounter[currentPoolId];
    delete poolRequiredTicket[currentPoolId];
    delete poolRequiredTicketPrice[currentPoolId];
    delete poolStartTime[currentPoolId];
    delete poolFindWinnerTime[currentPoolId];

    // Reset del identificador activo
    // currentPoolId = 0;
  }
}
