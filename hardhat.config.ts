import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-ethers";
import { HardhatUserConfig } from "hardhat/config";
import { existsSync, readFileSync } from 'fs';
import { chain, chainID } from "./constants";
const { vars } = require("hardhat/config");

const privKeyFile = '.private_key'
let privateKey = '';

if (existsSync(privKeyFile)) {
  privateKey = readFileSync(privKeyFile, "utf-8");
}

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.17",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  networks: {
    [chain.Ethereum]: {
      url: vars.get("ETHEREUM_RPC_URL"),
    },
    [chain.Arbitrum]: {
      url: vars.get("ARBITRUM_RPC_URL"),
    },
    [chain.Avalanche]: {
      url: vars.get("AVALANCHE_RPC_URL"),
    },
    [chain.Optimism]: {
      url: vars.get("OPTIMISM_RPC_URL"),
    },
    [chain.Base]: {
      url: vars.get("BASE_RPC_URL"),
    },
    [chain.Polygon]: {
      url: vars.get("POLYGON_RPC_URL"),
    },
    [chain.EthereumGoerli]: {
      url: vars.get("ETHEREUM_GOERLI_RPC_URL"),
    },
    [chain.AvalancheTestNet]: {
      url: vars.get("AVALANCHE_TESTNET_RPC_URL"),
    },
    [chain.ArbitrumGoerli]: {
      url: vars.get("ARBITRUM_GOERLI_RPC_URL"),
    },
    [chain.OptimismGoerli]: {
      url: vars.get("OPTIMISM_GOERLI_RPC_URL"),
    },
    [chain.BaseGoerli]: {
      url: vars.get("BASE_GOERLI_RPC_URL"),
    },
  },

  etherscan: {
    apiKey: {
      mainnet: vars.get("ETHEREUM_API_KEY"),
      arbitrumOne: vars.get("ARBITRUM_API_KEY"),
      avalanche: vars.get("AVALANCHE_API_KEY"),
      optimisticEthereum: vars.get("OPTIMISM_API_KEY"),
      Base: vars.get("BASE_API_KEY"),
      polygon: vars.get("POLYGON_API_KEY"),
    },
    customChains: [
      {
        network: "Base",
        chainId: 8453,
        urls: {
          apiURL: "https://api.basescan.org/api",
          browserURL: "https://basescan.org"
        },
      }
    ]
  },

};

for (var net in config.networks) {
  if (net == 'hardhat') continue;

  config.networks[net]!.chainId = chainID[net as keyof typeof chainID];

  if (privateKey != '') {
    config.networks[net]!.accounts = [privateKey]
  }
}

export default config;
