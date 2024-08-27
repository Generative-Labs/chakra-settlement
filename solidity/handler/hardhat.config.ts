import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
require("@nomicfoundation/hardhat-toolbox");

import "@nomicfoundation/hardhat-ethers";

import "@nomicfoundation/hardhat-verify";
import "hardhat-contract-sizer";

const config: HardhatUserConfig = {
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
  },
  typechain: {
    outDir: "typechain",
    target: "ethers-v6",
  },
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  sourcify: {
    enabled: false,
  },
  etherscan: {
    apiKey: {
      chakradn: "<Key>",
    },
    customChains: [
      {
        network: "chakradn",
        chainId: 8545,
        urls: {
          apiURL: "https://explorer-dn.chakrachain.io/api",
          browserURL: "https://explorer-dn.chakrachain.io",
        },
      },
    ],
  },
  networks: {
    localhost: {
      url: "http://localhost:8545",
    },
    anvil: {
      url: "http://127.0.0.1:8545",
      accounts: [
        "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
      ]
    },
    chakradn: {
      chainId: 8545,
      url: "https://rpcv1-dn-1.chakrachain.io",
    },
  },
};

export default config;
