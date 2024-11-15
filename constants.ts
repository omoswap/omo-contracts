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
    Scroll = "Scroll",
    Metis = "Metis",
    zkSync = "zkSync",
    Blast = "Blast",
    Mantle = "Mantle",
    Linea = "Linea",

    // TestNets
    EthereumSepolia = 'EthereumSepolia',
    AvalancheTestNet = 'AvalancheTestNet',
    ArbitrumSepolia = 'ArbitrumSepolia',
    OptimismSepolia = 'OptimismSepolia',
    BaseSepolia = 'BaseSepolia',
    BNBChainTestnet = 'BNBChainTestnet',
    CeloTestnet = "CeloTestnet",
    ScrollTestnet = "ScrollTestnet",
}

export enum chainID {
    // MainNets
    Ethereum = 1,
    Optimism = 10,
    BNBChain = 56,
    Gnosis = 100,
    Polygon = 137,
    Fantom = 250,
    zkSync = 324,
    Mantle = 5000,
    Base = 8453,
    Arbitrum = 42161,
    Celo = 42220,
    Avalanche = 43114,
    Scroll = 534352,
    Metis = 1088,
    Blast = 81457,
    Linea = 59144,

    // TestNets
    BNBChainTestnet = 97,
    EthereumSepolia = 11155111,
    AvalancheTestNet = 43113,
    ArbitrumSepolia = 421614,
    OptimismSepolia = 11155420,
    BaseSepolia = 84532,
    CeloTestnet = 44787,
    ScrollTestnet = 534351,
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
    chain.Scroll,
    chain.Metis,
    chain.zkSync,
    chain.Blast,
    chain.Mantle,
    chain.Linea,
]);

export function isDefinedNetwork(net: string) {
    return (<any>Object).values(chain).includes(net);
}

export function isMainnet(net: string) {
    return mainnets.has(net);
}
