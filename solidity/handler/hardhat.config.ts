
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import '@openzeppelin/hardhat-upgrades';

import "@nomicfoundation/hardhat-verify";
import "hardhat-contract-sizer";

const config: HardhatUserConfig = {
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
  },
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  sourcify: {
    enabled: false
  },
  etherscan: {
    apiKey: {
      chakradn: "<Key>"
    },
    customChains: [
      {
        network: "chakradn",
        chainId: 8545,
        urls: {
          apiURL: "https://explorer-dn.chakrachain.io/api",
          browserURL: "https://explorer-dn.chakrachain.io"
        }
      }
    ]
  },
  networks: {
    localhost: {
      url: "http://localhost:8545",
    },
    chakradn: {
      chainId: 8545,
      timeout: 200000, // 200 seconds max for running tests
      url: "https://rpcv1-dn-1.chakrachain.io",
      accounts: ["<Your account private key>"],
      gas: "auto",
      gasPrice: "auto"
    }
  }
};

export default config;
