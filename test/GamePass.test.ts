const { expect } = require('chai');

const { ethers } = require('hardhat');

describe('GamePass Contract', function () {
  let GamePass;
  let gamePass;
  let owner;
  let addr1;
  let addr2;
  let signers;

  beforeEach(async function () {
    [owner, addr1, addr2, ...signers] = await ethers.getSigners();

    GamePass = await ethers.getContractFactory('GamePass');
    gamePass = await GamePass.deploy(5);

    await gamePass.waitForDeployment();
  });

  it('should create a new game with valid parameters', async function () {
    const minPlayers = 2;
    const maxPlayers = 5;
    const entryFee = ethers.parseEther('0.01'); // 0.01 Ether

    // Guardamos el gameIdCounter actual antes de la llamada
    const initialGameIdCounter = await gamePass.gameIdCounter();

    // Llamamos a la función createGame
    // Como es `onlyOwner`, el `owner` debe ser quien la llama.
    // `.connect(owner)` asegura que la transacción se envíe desde la cuenta del owner.
    await gamePass.connect(owner).createGame(minPlayers, maxPlayers, entryFee);

    // Verificaciones (Assertions):

    // 1. Verificar que el gameIdCounter se ha incrementado
    expect(await gamePass.gameIdCounter()).to.equal(initialGameIdCounter + 1n); // Usamos 'n' para BigInt

    // 2. Obtener el juego recién creado usando el ID esperado
    const newGameId = initialGameIdCounter; // El ID del juego creado es el contador ANTES de incrementarse
    const game = await gamePass.games(newGameId); // Accedemos a la variable de estado pública 'games'

    // 3. Verificar los detalles del juego
    expect(game.creator).to.equal(owner.address);
    expect(game.minPlayers).to.equal(minPlayers);
    expect(game.maxPlayers).to.equal(maxPlayers);
    expect(game.entryFee).to.equal(entryFee);
    expect(game.pool).to.equal(0);
    expect(game.status).to.equal(0); // 0 = GameStatus.Sale (según tu enum)
    expect(game.playerCount).to.equal(0);
    expect(game.winner).to.equal(ethers.ZeroAddress); // address(0) en Hardhat/ethers.js es ethers.ZeroAddress
    expect(game.resultHash).to.equal(ethers.ZeroHash); // bytes32(0) en Hardhat/ethers.js es ethers.ZeroHash
    expect(game.collectedFee).to.equal(0);
  });
});
