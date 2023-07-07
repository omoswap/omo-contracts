import { smock } from "@defi-wonderland/smock";
import { setBalance } from "@nomicfoundation/hardhat-network-helpers";
import { ethers } from "hardhat";
import * as abis from "./abis";
import { getWalletByIndex, parseEther, zeroAddress } from "./utilities";

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
    const pusdcToken = await deployERC20TokenFixture("pUSDC", "pUSDC", 6);
    const bridgeFactroy = await ethers.getContractFactory("Bridge");
    const callProxyFactory = await ethers.getContractFactory("CallProxy");

    const mockTokenMessenger = await mockTokenMessengerFixture();
    const mockMessageTransmitter = await mockMessageTransmitterFixture(owner.address, usdcToken.address);
    const mockPool = await mockPoolFixture();

    mockTokenMessenger.localMessageTransmitter.returns(mockMessageTransmitter.address);

    const bridge = await bridgeFactroy.deploy(mockTokenMessenger.address, owner.address, owner.address, usdcToken.address);
    const callProxy = await callProxyFactory.deploy();
    await callProxy.setBridge(bridge.address);

    const ONE = parseEther("100");
    await setBalance(owner.address, ONE);
    await setBalance(user.address, ONE);

    await usdcToken.mint(owner.address, 1000);
    await usdcToken.mint(mockMessageTransmitter.address, 1000);
    await usdcToken.mint(mockPool.address, 1000);
    await pusdcToken.mint(mockPool.address, 1000);
    await usdcToken.approve(bridge.address, 1000);

    return { bridge, callProxy, owner, user, usdcToken, pusdcToken, mockPool, mockMessageTransmitter };
}
