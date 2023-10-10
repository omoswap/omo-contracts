import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-ethers";
import { HardhatUserConfig } from "hardhat/config";
import { readFileSync } from 'fs';
import { chain } from "./constants";

const privateKey = readFileSync('.private_key', 'utf-8');

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
      chainId: 1,
      accounts: [privateKey],
      url: "https://ethereum.publicnode.com",
    },
    [chain.Arbitrum]: {
      chainId: 42161,
      accounts: [privateKey],
      url: "https://endpoints.omniatech.io/v1/arbitrum/one/public",
    },
    [chain.Avalanche]: {
      chainId: 43114,
      accounts: [privateKey],
      url: "https://endpoints.omniatech.io/v1/avax/mainnet/public",
    },
    [chain.Optimism]: {
      chainId: 10,
      accounts: [privateKey],
      url: "https://endpoints.omniatech.io/v1/op/mainnet/public",
    },
    [chain.EthereumGoerli]: {
      chainId: 5,
      url: "https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161",
      accounts: [privateKey],
      gas: "auto",
      gasPrice: "auto",
    },
    [chain.AvalancheTestNet]: {
      chainId: 43113,
      url: "https://avalanche-fuji-c-chain.publicnode.com",
      accounts: [privateKey],
      gas: "auto",
      gasPrice: "auto",
    },
    [chain.ArbitrumGoerli]: {
      chainId: 421613,
      url: "https://endpoints.omniatech.io/v1/arbitrum/goerli/public",
      accounts: [privateKey],
      gas: "auto",
      gasPrice: "auto",
    },
    [chain.OptimismGoerli]: {
      chainId: 420,
      url: "https://endpoints.omniatech.io/v1/op/goerli/public",
      accounts: [privateKey],
      gas: "auto",
      gasPrice: "auto",
    },
    [chain.BaseGoerli]: {
      chainId: 84531,
      url: "https://goerli.base.org",
      accounts: [privateKey],
      gas: "auto",
      gasPrice: "auto",
    },
  },
};

export default config;
