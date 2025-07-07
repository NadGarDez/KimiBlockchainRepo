import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  networks: {
    local: { // Un posible nombre de red para tu nodo local
      url: 'http://localhost:8545',//"http://192.168.1.103:8545",
      chainId: 31337, // O el chainId correcto de tu nodo local
      // Si necesitas especificar cuentas para esta red:
      // accounts: ["0x...tu-clave-privada...", "...otra-clave..."],
      mining: {
        auto: false,
        interval: 100
      }
    },

  }
};

export default config;
