import "@nomicfoundation/hardhat-toolbox"; // comment out when compiling for zkSync
import "@nomiclabs/hardhat-ethers";
import { HardhatUserConfig } from "hardhat/config";
import { existsSync, readFileSync } from 'fs';
import { chain, chainID } from "./constants";

const { vars } = require("hardhat/config");

const privKeyFile = '.private_key'
let privateKey = '';

if (existsSync(privKeyFile)) {
  privateKey = readFileSync(privKeyFile, "utf-8");
  privateKey = privateKey.replace(/\s/g, "");
}

const config: HardhatUserConfig = {
  // defaultNetwork: chain.zkSync, // uncomment when compiling for zkSync
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
    [chain.BNBChain]: {
      url: vars.get("BNBCHAIN_RPC_URL"),
    },
    [chain.Celo]: {
      url: vars.get("CELO_RPC_URL"),
    },
    [chain.Scroll]: {
      url: vars.get("SCROLL_RPC_URL"),
    },
    [chain.Metis]: {
      url: vars.get("METIS_RPC_URL"),
    },
    [chain.zkSync]: {
      url: vars.get("ZKSYNC_RPC_URL"),
      // zksync: true,
      // ethNetwork: chain.Ethereum,
      // verifyURL: "https://zksync2-mainnet-explorer.zksync.io/contract_verification",
    },
    [chain.Blast]: {
      url: vars.get("BLAST_RPC_URL"),
    },
    [chain.Mantle]: {
      url: vars.get("MANTLE_RPC_URL"),
    },
    [chain.EthereumSepolia]: {
      url: vars.get("ETHEREUM_SEPOLIA_RPC_URL"),
    },
    [chain.AvalancheTestNet]: {
      url: vars.get("AVALANCHE_TESTNET_RPC_URL"),
    },
    [chain.ArbitrumSepolia]: {
      url: vars.get("ARBITRUM_SEPOLIA_RPC_URL"),
    },
    [chain.OptimismSepolia]: {
      url: vars.get("OPTIMISM_SEPOLIA_RPC_URL"),
    },
    [chain.BaseSepolia]: {
      url: vars.get("BASE_SEPOLIA_RPC_URL"),
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
      bsc: vars.get("BNBCHAIN_API_KEY"),
      Celo: vars.get("CELO_API_KEY"),
      Scroll: vars.get("SCROLL_API_KEY"),
      zkSync: vars.get("ZKSYNC_API_KEY"),
      Blast: vars.get("BLAST_API_KEY"),
      Mantle: vars.get("MANTLE_API_KEY"),
    },
    customChains: [
      {
        network: "Base",
        chainId: 8453,
        urls: {
          apiURL: "https://api.basescan.org/api",
          browserURL: "https://basescan.org"
        },
      },
      {
        network: chain.Celo,
        chainId: chainID.Celo,
        urls: {
          apiURL: "https://api.celoscan.io/api",
          browserURL: "https://celoscan.io",
        },
      },
      {
        network: chain.Scroll,
        chainId: chainID.Scroll,
        urls: {
          apiURL: "https://api.scrollscan.com/api",
          browserURL: "https://scrollscan.com",
        },
      },
      {
        network: chain.zkSync,
        chainId: chainID.zkSync,
        urls: {
          apiURL: "https://api-era.zksync.network/api",
          browserURL: "https://era.zksync.network",
        },
      },
      {
        network: chain.Blast,
        chainId: chainID.Blast,
        urls: {
          apiURL: "https://api.blastscan.io/api",
          browserURL: "https://blastscan.io",
        },
      },
      {
        network: chain.Mantle,
        chainId: chainID.Mantle,
        urls: {
          apiURL: "https://api.mantlescan.xyz/api",
          browserURL: "https://mantlescan.xyz",
        },
      },
    ]
  },

  // zksolc: {
  //   version: "latest",
  //   settings: {}
  // },
};

for (var net in config.networks) {
  if (net == 'hardhat') continue;

  config.networks[net]!.chainId = chainID[net as keyof typeof chainID];

  if (privateKey != '') {
    config.networks[net]!.accounts = [privateKey]
  }
}

export default config;
