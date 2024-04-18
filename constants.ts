export enum chain {
    // MainNets
    Ethereum = 'Ethereum',
    Optimism = "Optimism",
    Polygon = "Polygon",
    Arbitrum = "Arbitrum",
    Avalanche = "Avalanche",
    Base = "Base",
    BNBChain = "BNBChain",
    Celo = "Celo",

    // TestNets
    EthereumSepolia = 'EthereumSepolia',
    AvalancheTestNet = 'AvalancheTestNet',
    ArbitrumSepolia = 'ArbitrumSepolia',
    OptimismSepolia = 'OptimismSepolia',
    BaseSepolia = 'BaseSepolia',
    BNBChainTestnet = 'BNBChainTestnet',
    CeloTestnet = "CeloTestnet"
}

export enum chainID {
    // MainNets
    Ethereum = 1,
    Optimism = 10,
    BNBChain = 56,
    Gnosis = 100,
    Polygon = 137,
    Fantom = 250,
    Base = 8453,
    Arbitrum = 42161,
    Celo = 42220,
    Avalanche = 43114,

    // TestNets
    BNBChainTestnet = 97,
    EthereumSepolia = 11155111,
    AvalancheTestNet = 43113,
    ArbitrumSepolia = 421614,
    OptimismSepolia = 11155420,
    BaseSepolia = 84532,
    CeloTestnet = 44787,
}

const mainnets = new Set<string>([
    chain.Ethereum,
    chain.Optimism,
    chain.Polygon,
    chain.Arbitrum,
    chain.Avalanche,
    chain.Base,
    chain.BNBChain,
    chain.Celo,
]);

export function isDefinedNetwork(net: string) {
    return (<any>Object).values(chain).includes(net);
}

export function isMainnet(net: string) {
    return mainnets.has(net);
}
