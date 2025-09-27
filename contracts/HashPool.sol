// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.28;

contract HashPool {
  mapping(uint => address) public contestants;
  mapping(uint => bytes32) hashes;
  mapping(address => bool) public isRegistered;

  address public winner;
  address public owner;

  enum PoolState {
    RegistrationOpen,
    RegistrationClosed,
    CalculatingWinner,
    AwardingPrizes,
    GameEnded
  }

  uint public minContestants;
  uint public maxContestants;
  uint contestantCounter = 1;

  string public requiredTicket;

  uint256 startTime;
  uint256 findWinnerTime;

  PoolState public poolStatus;
  event PoolStatusChanged(PoolState previousStatus, PoolState newStatus);

  function setPoolStatus(PoolState newStatus) internal {
    PoolState previousStatus = poolStatus;
    poolStatus = newStatus;
    emit PoolStatusChanged(previousStatus, newStatus);
  }

  modifier onlyOwner() {
    require(msg.sender == owner, 'Solo el propietario es el gestor.');
    _;
  }

  constructor(
    uint _minContestants,
    uint _maxContestants,
    string memory _requiredTicket,
    uint256 _findWinnerTime
  ) {
    minContestants = _minContestants;
    maxContestants = _maxContestants;
    requiredTicket = _requiredTicket;
    findWinnerTime = _findWinnerTime;
    startTime = block.timestamp;
    owner = msg.sender;
    setPoolStatus(PoolState.RegistrationOpen);
  }

  function poolRegistration(bytes32 constestantSign) public {
    require(poolStatus == PoolState.RegistrationOpen, 'Registro terminado');
    require(contestantCounter < maxContestants, 'No hay puestos disponibles');

    require(!isRegistered[msg.sender], 'Ya esta registrado');

    require(constestantSign != bytes32(0), 'Hash mal formateado');

    hashes[contestantCounter] = constestantSign;
    contestants[contestantCounter] = msg.sender;
    isRegistered[msg.sender] = true;
    contestantCounter++;

    if (contestantCounter == maxContestants) {
        setPoolStatus(PoolState.RegistrationClosed);
    }
  }

  function finishPool() public onlyOwner {
    require(poolStatus == PoolState.AwardingPrizes);
    setPoolStatus(PoolState.GameEnded);
    setPoolStatus(PoolState.GameEnded);
  }

  function selectWinner() public onlyOwner {
    require(poolStatus == PoolState.RegistrationClosed);
    setPoolStatus(PoolState.CalculatingWinner);
    winner = contestants[0];
  }

  function awaringWinner() public onlyOwner {
    require(poolStatus == PoolState.CalculatingWinner);
    setPoolStatus(PoolState.AwardingPrizes);
    // connect with other contract to send the native coin tokens
  }
}
