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
  address public admin;
  address public winner;

  // Estado y Contadores (OPTIMIZADOS PARA PACKING)
  PoolState public poolStatus;
  uint16 public maxContestants;
  uint16 public contestantCounter = 0;
  uint16 public preRegistrationCounter = 0;
  TicketType public requiredTicket;

  uint256 startTime;
  uint256 findWinnerTime;

  bytes32 public combinedHash = 0;
  mapping(uint16 => address) public contestants;
  mapping(address => uint256) public participantTicket;
  mapping(address => bytes32) public contestantSigns;

  // =================================================================
  // 4. EVENTOS
  // =================================================================

  event PoolStatusChanged(PoolState previousStatus, PoolState newStatus);
  event TicketRefunded(address indexed participant, uint256 ticketId);
  event PreRegistrationEvent(address indexed participant, uint256 ticketId);
  event SuccessfulRegistration(address indexed participant, uint256 ticketId);
  event FailedRegistration(
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

  // =================================================================
  // 6. CONSTRUCTOR
  // =================================================================

  constructor(
    uint16 _maxContestants,
    TicketType _requiredTicket,
    uint256 _findWinnerTime,
    address _ticketManagerAddress,
    address _adminAddress
  ) {
    maxContestants = _maxContestants;
    requiredTicket = _requiredTicket;
    findWinnerTime = _findWinnerTime;
    startTime = block.timestamp;
    owner = msg.sender;
    admin = _adminAddress;
    ticketManager = ITicketManager(_ticketManagerAddress);
    setPoolStatus(PoolState.RegistrationOpen);
  }

  // =================================================================
  // 7. FUNCIONES MUTABLES (Lógica de Juego)
  // =================================================================

  function setPoolStatus(PoolState newStatus) internal {
    PoolState previousStatus = poolStatus;
    poolStatus = newStatus;
    emit PoolStatusChanged(previousStatus, newStatus);
  }

  function PreRegistration(uint ticketId) public {
    require(poolStatus == PoolState.RegistrationOpen, 'Registro terminado');
    require(preRegistrationCounter < maxContestants, 'Cupo maximo alcanzado.');

    preRegistrationCounter++;

    emit PreRegistrationEvent(msg.sender, ticketId);

    if (preRegistrationCounter == maxContestants) {
      setPoolStatus(PoolState.ValidatingEntries);
    }
  }

  /**
   * @notice Registra un lote de participantes, sus tickets y sus firmas de entropía.
   * Esta función maximiza el ahorro de Gas al procesar múltiples registros en una sola transacción.
   */
  function registerBatch(
    address[] calldata _participants,
    uint256[] calldata _ticketIds,
    bytes32[] calldata _contestantSigns
  ) public onlyAdmin {
    require(poolStatus == PoolState.ValidatingEntries, 'Registro terminado');
    require(_participants.length > 0, 'Batch vacio.');
    require(
      _participants.length == _ticketIds.length &&
        _ticketIds.length == _contestantSigns.length,
      'Arrays deben tener la misma longitud.'
    );

    uint256 batchSize = _participants.length;
    require(
      contestantCounter + batchSize <= maxContestants,
      'El batch excede el cupo maximo.'
    );

    bytes32 currentCombinedHash = combinedHash;
    uint16 currentCounter = contestantCounter;

    for (uint16 i = 0; i < batchSize; i++) {
      contestants[currentCounter] = _participants[i];
      participantTicket[_participants[i]] = _ticketIds[i];
      contestantSigns[_participants[i]] = _contestantSigns[i];
      // ticketManager.markTicketAsUsed(_ticketIds[i]);
      currentCombinedHash = keccak256(
        abi.encodePacked(currentCombinedHash, _contestantSigns[i])
      );

      emit SuccessfulRegistration(_participants[i], _ticketIds[i]);
      currentCounter++;
    }

    combinedHash = currentCombinedHash;
    contestantCounter = currentCounter;

    if (contestantCounter >= maxContestants) {
      setPoolStatus(PoolState.RegistrationClosed);
    } else {
      preRegistrationCounter = contestantCounter;
      setPoolStatus(PoolState.RegistrationOpen);
    }
  }

  function selectWinner() public onlyAdmin {
    require(
      poolStatus == PoolState.RegistrationClosed ||
        (block.timestamp >= findWinnerTime &&
          poolStatus == PoolState.RegistrationOpen),
      'El registro aun no cierra o no ha pasado el tiempo.'
    );

    if (contestantCounter == 0) {
      setPoolStatus(PoolState.GameEnded);
      return;
    }

    if (poolStatus == PoolState.RegistrationOpen) {
      setPoolStatus(PoolState.RegistrationClosed);
    }

    uint256 randomNumberSeed = uint256(combinedHash);

    uint256 winningIndex = randomNumberSeed % uint256(contestantCounter);

    winner = contestants[uint16(winningIndex)];

    setPoolStatus(PoolState.AwardingPrizes);
  }

  function awaringWinner() public onlyAdmin {
    require(
      poolStatus == PoolState.AwardingPrizes,
      'El ganador ya fue premiado o no esta en fase de premiacion.'
    );

    address payable winnerAddress = payable(winner);
    require(winnerAddress != address(0), 'El ganador no esta establecido.');

    uint256 totalPrize = _calculatePrizePool();

    ticketManager.awardPrize(winnerAddress, totalPrize);

    setPoolStatus(PoolState.GameEnded);
  }

  function failRegistration(
    address _participant,
    uint ticketId,
    string calldata reason
  ) public onlyAdmin {
    require(poolStatus == PoolState.ValidatingEntries, 'Registro terminado');
    require(
      participantTicket[_participant] == 0,
      'Participante ya registrado.'
    );
    emit FailedRegistration(_participant, ticketId, reason);
  }

  /**
   * @notice Permite al participante solicitar la devolución de su ticket si el pool terminó SIN ganador.
   */
  function requestRefund() public {
    require(poolStatus == PoolState.GameEnded, 'El pool aun no termina.');
    require(winner == address(0), 'El ganador ya fue seleccionado y premiado.');

    uint256 ticketId = participantTicket[msg.sender];
    require(ticketId != 0, 'No estas registrado en este pool.');

    delete participantTicket[msg.sender];

    ticketManager.unmarkTicketAsUsed(ticketId);

    emit TicketRefunded(msg.sender, ticketId);
  }

  // =================================================================
  // 8. FUNCIONES DE VISTA (View y Pure)
  // =================================================================

  function _getRequiredTicketPrice() internal view returns (uint) {
    TicketManagerStructs.Variant memory variant = ticketManager
      .getVariantDetails(requiredTicket);
    return variant.ticketPrice;
  }

  function _calculatePrizePool() internal view returns (uint256 totalPrize) {
    uint256 singleTicketPrice = _getRequiredTicketPrice();
    totalPrize = singleTicketPrice * uint256(contestantCounter);
  }

  function getPoolStatus() external view returns (PoolState) {
    return poolStatus;
  }

  function getPoolInfo()
    external
    view
    returns (
      TicketType requiredTicketType,
      uint16 maxContestantsCount,
      uint16 currentContestants,
      uint256 prizePool,
      uint256 winnerSelectionTime
    )
  {
    return (
      requiredTicket,
      maxContestants,
      contestantCounter,
      _calculatePrizePool(),
      findWinnerTime
    );
  }

  function getMyTicketId(address _participant) external view returns (uint256) {
    return participantTicket[_participant];
  }

  function getContestantAddresses() external view returns (address[] memory) {
    address[] memory participants = new address[](uint256(contestantCounter));

    for (uint i = 0; i < contestantCounter; i++) {
      participants[i] = contestants[uint16(i)];
    }

    return participants;
  }
}
