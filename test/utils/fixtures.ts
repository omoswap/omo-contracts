import { smock } from "@defi-wonderland/smock";
import { setBalance } from "@nomicfoundation/hardhat-network-helpers";
import { ethers } from "hardhat";
import * as abis from "./abis";
import { addressToBytes32, getWalletByIndex, parseEther, zeroAddress } from "./utilities";

export async function deployERC20TokenFixture(name = "ERC20Token", symbol = "TOKEN", decimals = 18) {
    const factory = await ethers.getContractFactory("ERC20Token");
    const ERC20Token = await factory.deploy(name, symbol, decimals);
    return ERC20Token;
}

export async function mockTokenMessengerFixture() {
    const tokenMessenger = await smock.fake(abis.tokenMessenger);
    tokenMessenger.depositForBurnWithCaller.returns(1);
    return tokenMessenger;
}

export async function mockMessageTransmitterFixture(_attester: string = zeroAddress, _usdc: string = zeroAddress) {
    const factory = await ethers.getContractFactory("MockMessageTransmitter");
    const messageTransmitter = await factory.deploy(_attester, _usdc);
    return messageTransmitter;
}

export async function mockPoolFixture() {
    const factory = await ethers.getContractFactory("MockPool");
    const pool = await factory.deploy();
    return pool;
}

export async function deployBridgeFixture() {
    const owner = getWalletByIndex(0);
    const user = getWalletByIndex(1);
    const usdcToken = await deployERC20TokenFixture("USDC", "USDC", 6);
    const usdtToken = await deployERC20TokenFixture("USDT", "USDT", 6);
    const bridgeFactory = await ethers.getContractFactory("Bridge");
    const callProxyFactory = await ethers.getContractFactory("CallProxy");

    const mockTokenMessenger = await mockTokenMessengerFixture();
    const mockMessageTransmitter = await mockMessageTransmitterFixture(owner.address, usdcToken.address);
    const mockPool = await mockPoolFixture();

    mockTokenMessenger.localMessageTransmitter.returns(mockMessageTransmitter.address);

    const bridge = await bridgeFactory.deploy(mockTokenMessenger.address, owner.address, owner.address);
    const callProxy = await callProxyFactory.deploy();
    await callProxy.setBridge(bridge.address);

    const ONE = parseEther("100");
    await setBalance(owner.address, ONE);
    await setBalance(user.address, ONE);

    await usdcToken.mint(owner.address, 1000);
    await usdcToken.mint(mockMessageTransmitter.address, 1000);
    await usdcToken.mint(mockPool.address, 1000);
    await usdtToken.mint(mockPool.address, 1000);
    await usdcToken.approve(bridge.address, 1000);

    return { bridge, callProxy, owner, user, usdcToken, usdtToken, mockPool, mockMessageTransmitter, mockTokenMessenger };
}

export async function deployAggregatorFixture() {
    const bridgeFixture = await deployBridgeFixture();

    const tokenA = await deployERC20TokenFixture("tokenA", "tokenA", 6);
    const tokenB = await deployERC20TokenFixture("tokenB", "tokenB", 6);
    const tokenC = await deployERC20TokenFixture("tokenC", "tokenC", 6);
    const path = [tokenA.address, tokenB.address, tokenC.address];

    const WETHFactory = await ethers.getContractFactory("WETH");
    const WETH = await WETHFactory.deploy();

    const OMOEthereumUniswapAggregatorFactory = await ethers.getContractFactory("OMOEthereumUniswapAggregator");
    const OMOEthereumUniswapAggregator = await OMOEthereumUniswapAggregatorFactory.deploy(bridgeFixture.owner.address);

    const mockUniswapV2FactoryFactory = await ethers.getContractFactory("MockUniswapV2Factory");
    const mockUniswapV2Factory = await mockUniswapV2FactoryFactory.deploy();

    await mockUniswapV2Factory.createPair(WETH.address, tokenA.address);
    await mockUniswapV2Factory.createPair(tokenA.address, tokenB.address);
    await mockUniswapV2Factory.createPair(tokenB.address, tokenC.address);
    console.log("MockUniswapV2Factory - init core hash: ", await mockUniswapV2Factory.generateInitCode());

    const mockUniswapV2PairFactory = await ethers.getContractFactory("MockUniswapV2Pair");

    const mockUniswapV2PairWETHA = mockUniswapV2PairFactory.attach(
        await mockUniswapV2Factory.getPair(WETH.address, tokenA.address)
    );
    const mockUniswapV2PairAB = mockUniswapV2PairFactory.attach(
        await mockUniswapV2Factory.getPair(tokenA.address, tokenB.address)
    );
    const mockUniswapV2PairBC = mockUniswapV2PairFactory.attach(
        await mockUniswapV2Factory.getPair(tokenB.address, tokenC.address)
    );

    await tokenA.mint(bridgeFixture.owner.address, 10000);
    await tokenA.approve(OMOEthereumUniswapAggregator.address, 10000);
    await WETH.deposit({ value: 10000 });
    await WETH.transfer(mockUniswapV2PairWETHA.address, 10000);
    await tokenA.mint(mockUniswapV2PairWETHA.address, 10000);
    await tokenA.mint(mockUniswapV2PairAB.address, 10000);
    await tokenB.mint(mockUniswapV2PairAB.address, 10000);
    await tokenB.mint(mockUniswapV2PairBC.address, 10000);
    await tokenC.mint(mockUniswapV2PairBC.address, 10000);

    await bridgeFixture.bridge.bindBridge(1, addressToBytes32(bridgeFixture.bridge.address));
    await bridgeFixture.bridge.setCallProxy(bridgeFixture.callProxy.address);
    await OMOEthereumUniswapAggregator.setBridge(bridgeFixture.bridge.address);
    await OMOEthereumUniswapAggregator.setFactory(mockUniswapV2Factory.address);
    await OMOEthereumUniswapAggregator.setWETH(WETH.address);

    return {
        OMOEthereumUniswapAggregator,
        mockUniswapV2Factory,
        mockUniswapV2PairWETHA,
        mockUniswapV2PairAB,
        mockUniswapV2PairBC,
        WETH,
        path,
        tokenA,
        tokenB,
        tokenC,
        ...bridgeFixture,
    };
}
