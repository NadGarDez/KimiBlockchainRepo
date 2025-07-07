pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';

contract GamePass {
  address public owner;
  mapping(uint => Game) public games;
  mapping(uint => Ticket) public tickets;

  uint public gameIdCounter;
  uint public ticketIdCounter;

  uint public platformFeePercentage = 5;
  uint public accumulatedFees;

  enum GameStatus {
    Sale,
    Progress,
    Finished
  }

  struct Game {
    address creator;
    uint minPlayers;
    uint maxPlayers;
    uint entryFee;
    uint pool;
    GameStatus status;
    uint playerCount;
    bytes32 resultHash;
    bool paid; // Para rastrear si el premio ya se pagó a un ganador
    uint collectedFee; // Tarifa recolectada para este juego
    address winner;
  }

  struct Ticket {
    uint gameId;
    address owner;
    uint ticketId;
  }

  constructor(uint _platformFeePercentage) {
    owner = msg.sender;
    gameIdCounter = 1;
    ticketIdCounter = 1;
    require(
      _platformFeePercentage <= 100,
      'Platform fee percentage cannot exceed 100.'
    );
    platformFeePercentage = _platformFeePercentage;
    accumulatedFees = 0;
  }

  modifier onlyOwner() {
    require(msg.sender == owner, 'Only the owner can call this function.');
    _;
  }

  modifier inStatus(uint _gameId, GameStatus _status) {
    require(
      games[_gameId].status == _status,
      'Game is not in the required status.'
    );
    _;
  }

  function createGame(
    uint _minPlayers,
    uint _maxPlayers,
    uint _entryFee
  ) public onlyOwner {
    require(_minPlayers > 0, 'Minimum players must be greater than 0.');
    require(
      _maxPlayers >= _minPlayers,
      'Maximum players must be greater than or equal to minimum players.'
    );
    require(_entryFee > 0, 'Entry fee must be greater than 0.');

    uint newGameId = gameIdCounter;
    games[newGameId].creator = msg.sender;
    games[newGameId].minPlayers = _minPlayers;
    games[newGameId].maxPlayers = _maxPlayers;
    games[newGameId].entryFee = _entryFee;
    games[newGameId].pool = 0;
    games[newGameId].status = GameStatus.Sale;
    games[newGameId].playerCount = 0;
    games[newGameId].winner = address(0);
    games[newGameId].resultHash = bytes32(0);
    games[newGameId].collectedFee = 0;

    gameIdCounter++;

    //      emit GameCreated(newGameId, msg.sender, _minPlayers, _maxPlayers, _entryFee);
    //    emit GameStatusUpdated(newGameId, GameStatus.Sale);
  }

  function buyTicket(
    uint _gameId
  ) public payable inStatus(_gameId, GameStatus.Sale) {
    require(
      games[_gameId].playerCount < games[_gameId].maxPlayers,
      'Game is full.'
    );
    require(msg.value == games[_gameId].entryFee, 'Incorrect entry fee.');

    uint newTicketId = ticketIdCounter;

    tickets[newTicketId].gameId = _gameId;
    tickets[newTicketId].ticketId = newTicketId;
    tickets[newTicketId].owner = msg.sender;

    games[_gameId].pool += msg.value;
    games[_gameId].playerCount++;
    ticketIdCounter++;

    // emit TicketPurchased(_gameId, msg.sender, newTicketId, msg.value);
    ticketIdCounter++;

    //    emit TicketPurchased(_gameId, msg.sender, newTicketId, msg.value);
  }

  function updateGameStatus(
    uint _gameId,
    GameStatus _newStatus
  ) public onlyOwner {
    require(games[_gameId].creator != address(0), 'Game does not exist.');
    require(
      games[_gameId].status != _newStatus,
      'Game is already in this status.'
    );
    games[_gameId].status = _newStatus;
    // emit GameStatusUpdated(_gameId, _newStatus);
  }

  function announceWinners(
    uint _gameId,
    address _winner,
    bytes memory _signature
  ) public onlyOwner inStatus(_gameId, GameStatus.Progress) {
    require(
      _winner != address(0),
      'Number of winners must be between 1 and 3.'
    );

    bytes32 messageHash = keccak256(abi.encode(_gameId, _winner));
    address signer = ECDSA.recover(messageHash, _signature);
    require(signer == owner, 'Invalid signature from the backend.');

    games[_gameId].status = GameStatus.Finished;
    games[_gameId].winner = _winner;
    games[_gameId].resultHash = messageHash;
    games[_gameId].status = GameStatus.Finished;
    games[_gameId].resultHash = messageHash;

    //games[_gameId].winners = _winners;

    // emit GameStatusUpdated(_gameId, GameStatus.Finished);
    //emit WinnersAnnounced(_gameId, _winners, messageHash);
  }

  function distributeAllPrizes(
    uint _gameId,
    bytes memory _signature
  ) public onlyOwner inStatus(_gameId, GameStatus.Finished) {
    require(
      games[_gameId].winner != address(0),
      'No winners to distribute prizes to.'
    );
    uint platformFeeForGame = (games[_gameId].pool * platformFeePercentage) /
      100;
    games[_gameId].collectedFee = platformFeeForGame;
    accumulatedFees += platformFeeForGame;
    //   emit PlatformFeeCollected(_gameId, platformFeeForGame);

    uint prizeAmount = games[_gameId].pool - platformFeeForGame;
    address winner = games[_gameId].winner;
    bytes32 messageHash = keccak256(abi.encode(_gameId, winner, prizeAmount));

    address signer = ECDSA.recover(messageHash, _signature);
    require(signer == owner, 'Invalid signature for prize distribution.');

    payable(winner).transfer(prizeAmount);
    games[_gameId].pool -= prizeAmount;
    games[_gameId].paid = true;
    // emit PrizeDistributed(_gameId, winner, prizeAmount);
    //emit AllPrizesDistributed(_gameId);
  }

  function withdrawPlatformFees(bytes memory _signature) public onlyOwner {
    bytes32 messageHash = keccak256(abi.encode(accumulatedFees));
    address signer = ECDSA.recover(messageHash, _signature);
    require(signer == owner, 'Invalid signature for fee withdrawal.');

    uint amountToWithdraw = accumulatedFees;
    accumulatedFees = 0;
    payable(owner).transfer(amountToWithdraw);
    //  emit OwnerFeeWithdrawn(amountToWithdraw);
  }

  function getGameDetails(uint _gameId) public view returns (Game memory) {
    require(games[_gameId].creator != address(0), 'Game does not exist.');
    return games[_gameId];
  }

  function getTicketInfo(uint _ticketId) public view returns (Ticket memory) {
    require(tickets[_ticketId].owner != address(0), 'Ticket does not exist.');
    return tickets[_ticketId];
  }

  function getPlayerCount(uint _gameId) public view onlyOwner returns (uint) {
    require(games[_gameId].creator != address(0), 'Game does not exist.');
    return games[_gameId].playerCount;
  }

  function getGamePool(uint _gameId) public view returns (uint) {
    require(games[_gameId].creator != address(0), 'Game does not exist.');
    return games[_gameId].pool;
  }

  function getWinner(uint _gameId) public view returns (address) {
    require(
      games[_gameId].creator != address(0) &&
        games[_gameId].status == GameStatus.Finished,
      'Game not finished or does not exist.'
    );
    return games[_gameId].winner;
  }

  function getResultHash(uint _gameId) public view returns (bytes32) {
    require(
      games[_gameId].creator != address(0) &&
        games[_gameId].status == GameStatus.Finished,
      'Game not finished or does not exist.'
    );
    return games[_gameId].resultHash;
  }

  function getGameStatus(uint _gameId) public view returns (GameStatus) {
    require(games[_gameId].creator != address(0), 'Game does not exist.');
    return games[_gameId].status;
  }

  function getPlatformFeePercentage() public view returns (uint) {
    return platformFeePercentage;
  }

  function setPlatformFeePercentage(uint _newPercentage) public onlyOwner {
    require(_newPercentage <= 100, 'New percentage cannot exceed 100.');
    platformFeePercentage = _newPercentage;
  }

  function getAccumulatedFees() public view returns (uint) {
    return accumulatedFees;
  }
}
