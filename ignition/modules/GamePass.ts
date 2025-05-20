// ignition/modules/GamePassModule.ts

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const DEFAULT_PLATFORM_FEE_PERCENTAGE = 10; // Usamos la constante del contrato como valor por defecto

const GamePassModule = buildModule("GamePassModule", (m) => {
  // 1. Desplegar el contrato GamePass
  const platformFeePercentage = m.getParameter(
    "platformFeePercentage",
    DEFAULT_PLATFORM_FEE_PERCENTAGE
  );

  const gamePass = m.contract("GamePass", [platformFeePercentage]);

  // 2. (Opcional) Realizar algunas configuraciones iniciales después del despliegue
  // Por ejemplo, si tuvieras una función `setAdmin` o similar, podrías llamarla aquí.
  // const adminAddress = m.getParameter("adminAddress", "YOUR_ADMIN_ADDRESS");
  // m.call(gamePass, "setAdmin", [adminAddress]);

  // 3. (Opcional) Crear un juego inicial durante el despliegue
  // const minPlayers = m.getParameter("minPlayers", 1);
  // const maxPlayers = m.getParameter("maxPlayers", 5);
  // const entryFee = m.getParameter("entryFee", 1000000000000000n); // 0.001 ETH como ejemplo

  // const initialGame = m.call(gamePass, "createGame", [minPlayers, maxPlayers, entryFee]);

  return { gamePass, /* initialGame */}; // Exportamos el contrato desplegado y el juego inicial (si se crea)
});

export default GamePassModule;
