import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { Bridge__factory, ERC20Token } from "../typechain-types";
import { deployBridgeFixture, deployERC20TokenFixture } from "./utils/fixtures";
import {
    addressToBytes32,
    emptyString,
    getContractAccount,
    getWalletByIndex,
    signMessage,
    writeVarBytes,
    zeroAddress,
} from "./utils/utilities";

describe("bridge", () => {
    describe("constructor", () => {
        let owner: SignerWithAddress, usdcToken: ERC20Token, bridgeFactory: Bridge__factory;
        beforeEach(async () => {
            [owner] = await ethers.getSigners();
            usdcToken = await loadFixture(deployERC20TokenFixture);
            bridgeFactory = await ethers.getContractFactory("Bridge");
        });
        it("should revert deploy if tokenMessenger is zero", async () => {
            await expect(bridgeFactory.deploy(zeroAddress, owner.address, owner.address)).to.be.revertedWith(
                "tokenMessenger address cannot be zero"
            );
        });
        it("should revert deploy if attester is zero", async () => {
            await expect(bridgeFactory.deploy(owner.address, zeroAddress, owner.address)).to.be.revertedWith(
                "New attester must be nonzero"
            );
        });
        it("should revert deploy if feeCollector is zero", async () => {
            await expect(bridgeFactory.deploy(owner.address, owner.address, zeroAddress)).to.be.revertedWith(
                "feeCollector address cannot be zero"
            );
        });
        it("should deploy", async () => {
            const bridge = await bridgeFactory.deploy(owner.address, owner.address, owner.address);

            expect(await bridge.tokenMessenger()).to.be.equal(owner.address);
            expect(await bridge.feeCollector()).to.be.equal(owner.address);
        });
    });
    describe("bindBridge", () => {
        it("should revert bind targetBridge if not owner", async () => {
            const { user, bridge } = await loadFixture(deployBridgeFixture);
            await expect(bridge.connect(user).bindBridge(0, addressToBytes32(bridge.address))).to.be.revertedWith(
                "Ownable: caller is not the owner"
            );
        });
        it("should bind targetBridge", async () => {
            const { bridge } = await loadFixture(deployBridgeFixture);
            await expect(bridge.bindBridge(0, addressToBytes32(bridge.address)))
                .to.emit(bridge, "BindBridge")
                .withArgs(0, addressToBytes32(bridge.address.toLowerCase()));
        });
        it("should revert bind bindBridgeBatch if Inconsistent parameter lengths", async () => {
            const { bridge } = await loadFixture(deployBridgeFixture);
            await expect(
                bridge.bindBridgeBatch([0], [addressToBytes32(bridge.address), addressToBytes32(bridge.address)])
            ).to.be.revertedWith("Inconsistent parameter lengths");
        });
        it("should bind bindBridgeBatch", async () => {
            const { bridge } = await loadFixture(deployBridgeFixture);
            await expect(
                bridge.bindBridgeBatch([0, 1], [addressToBytes32(bridge.address), addressToBytes32(bridge.address)])
            )
                .to.emit(bridge, "BindBridgeBatch")
                .withArgs(
                    [0, 1],
                    [addressToBytes32(bridge.address.toLowerCase()), addressToBytes32(bridge.address.toLowerCase())]
                );
        });
    });
    describe("bridgeToken", () => {
        it("should revert disable bridgeToken if not owner", async () => {
            const { user, usdcToken, bridge } = await loadFixture(deployBridgeFixture);
            await expect(bridge.connect(user).disableBridgeToken(usdcToken.address)).to.be.revertedWith(
                "Ownable: caller is not the owner"
            );
        });
        it("should revert disable bridgeToken if address is zero", async () => {
            const { bridge } = await loadFixture(deployBridgeFixture);
            await expect(bridge.disableBridgeToken(zeroAddress)).to.be.revertedWith("token address cannot be zero");
        });
        it("should disable bridgeToken", async () => {
            const { usdcToken, bridge } = await loadFixture(deployBridgeFixture);
            await expect(bridge.disableBridgeToken(usdcToken.address))
                .to.emit(bridge, "DisableBridgeToken")
                .withArgs(usdcToken.address);
        });
        it("should revert enable bridgeToken if not owner", async () => {
            const { user, usdcToken, bridge } = await loadFixture(deployBridgeFixture);
            await expect(bridge.connect(user).enableBridgeToken(usdcToken.address)).to.be.revertedWith(
                "Ownable: caller is not the owner"
            );
        });
        it("should revert enable bridgeToken if address is zero", async () => {
            const { bridge } = await loadFixture(deployBridgeFixture);
            await expect(bridge.enableBridgeToken(zeroAddress)).to.be.revertedWith("token address cannot be zero");
        });
        it("should enable bridgeToken", async () => {
            const { usdcToken, bridge } = await loadFixture(deployBridgeFixture);

            await bridge.disableBridgeToken(usdcToken.address);
            expect(await bridge.disabledBridgeTokens(usdcToken.address)).to.be.equal(true);

            await expect(bridge.enableBridgeToken(usdcToken.address))
                .to.emit(bridge, "EnableBridgeToken")
                .withArgs(usdcToken.address);

            expect(await bridge.disabledBridgeTokens(usdcToken.address)).to.be.equal(false);
        });
    });
    describe("router", () => {
        it("should revert enable router if not owner", async () => {
            const { user, usdcToken, bridge } = await loadFixture(deployBridgeFixture);
            await expect(bridge.connect(user).enableRouter(usdcToken.address, 1)).to.be.revertedWith(
                "Ownable: caller is not the owner"
            );
        });
        it("should revert enable router if address is zero", async () => {
            const { bridge } = await loadFixture(deployBridgeFixture);
            await expect(bridge.enableRouter(zeroAddress, 1)).to.be.revertedWith("token address cannot be zero");
        });
        it("should enable router", async () => {
            const { usdcToken, bridge } = await loadFixture(deployBridgeFixture);
            await expect(bridge.enableRouter(usdcToken.address, 1))
                .to.emit(bridge, "EnableRoute")
                .withArgs(usdcToken.address, 1);
        });
        it("should revert disable router if not owner", async () => {
            const { user, usdcToken, bridge } = await loadFixture(deployBridgeFixture);
            await expect(bridge.connect(user).disableRoute(usdcToken.address, 1)).to.be.revertedWith(
                "Ownable: caller is not the owner"
            );
        });
        it("should revert disable router if address is zero", async () => {
            const { bridge } = await loadFixture(deployBridgeFixture);
            await expect(bridge.disableRoute(zeroAddress, 1)).to.be.revertedWith("token address cannot be zero");
        });
        it("should disable router", async () => {
            const { usdcToken, bridge } = await loadFixture(deployBridgeFixture);

            await bridge.enableRouter(usdcToken.address, 1);
            expect(await bridge.disabledRoutes(usdcToken.address, 1)).to.be.equal(false);

            await expect(bridge.disableRoute(usdcToken.address, 1))
                .to.emit(bridge, "DisableRoute")
                .withArgs(usdcToken.address, 1);

            expect(await bridge.disabledRoutes(usdcToken.address, 1)).to.be.equal(true);
        });
    });
    describe("tokenMessenger", () => {
        it("should revert if tokenMessenger address is zero", async () => {
            const { bridge } = await loadFixture(deployBridgeFixture);
            await expect(bridge.setTokenMessenger(zeroAddress)).to.be.revertedWith("tokenMessenger address cannot be zero");
        });
        it("should revert if not owner", async () => {
            const { user, bridge } = await loadFixture(deployBridgeFixture);
            await expect(bridge.connect(user).setTokenMessenger(user.address)).to.be.revertedWith(
                "Ownable: caller is not the owner"
            );
        });
        it("should set tokenMessenger", async () => {
            const { bridge, user } = await loadFixture(deployBridgeFixture);
            await expect(bridge.setTokenMessenger(user.address)).to.emit(bridge, "SetTokenMessenger").withArgs(user.address);
        });
        it("should get messageTransmitter", async () => {
            const { bridge, mockMessageTransmitter } = await loadFixture(deployBridgeFixture);
            expect(await bridge.getMessageTransmitter()).to.be.equal(mockMessageTransmitter.address);
        });
    });
    describe("store", () => {
        it("should revert setCallProxy if not owner", async () => {
            const { user, bridge } = await loadFixture(deployBridgeFixture);
            await expect(bridge.connect(user).setCallProxy(user.address)).to.be.revertedWith(
                "Ownable: caller is not the owner"
            );
        });
        it("should setCallProxy", async () => {
            const { bridge, callProxy } = await loadFixture(deployBridgeFixture);
            await expect(bridge.setCallProxy(callProxy.address)).to.emit(bridge, "SetCallProxy").withArgs(callProxy.address);
        });
        it("should revert setFeeCollector if not owner", async () => {
            const { user, bridge } = await loadFixture(deployBridgeFixture);
            await expect(bridge.connect(user).setFeeCollector(user.address)).to.be.revertedWith(
                "Ownable: caller is not the owner"
            );
        });
        it("should revert setFeeCollector to zero", async () => {
            const { bridge } = await loadFixture(deployBridgeFixture);
            await expect(bridge.setFeeCollector(zeroAddress)).to.be.revertedWith("feeCollector address cannot be zero");
        });
        it("should setFeeCollector", async () => {
            const { bridge, user } = await loadFixture(deployBridgeFixture);
            await expect(bridge.setFeeCollector(user.address)).to.emit(bridge, "SetFeeCollector").withArgs(user.address);
        });
    });
    describe("rescue", () => {
        it("should revert rescueFund if not owner", async () => {
            const { user, bridge, usdcToken } = await loadFixture(deployBridgeFixture);
            await expect(bridge.connect(user).rescueFund(usdcToken.address)).to.be.revertedWith(
                "Ownable: caller is not the owner"
            );
        });
        it("should rescueFund", async () => {
            const { owner, bridge, usdcToken } = await loadFixture(deployBridgeFixture);
            const amount = 10;
            await usdcToken.transfer(bridge.address, amount);
            await expect(bridge.rescueFund(usdcToken.address)).to.changeTokenBalances(
                usdcToken,
                [owner, bridge],
                [amount, -amount]
            );
        });
        it("should revert rescueNative if not owner", async () => {
            const { user, bridge, usdcToken } = await loadFixture(deployBridgeFixture);
            await expect(bridge.connect(user).rescueFund(usdcToken.address)).to.be.revertedWith(
                "Ownable: caller is not the owner"
            );
        });
        it("should rescueNative", async () => {
            const { owner, bridge } = await loadFixture(deployBridgeFixture);
            const amount = 10;
            await owner.sendTransaction({ to: bridge.address, value: amount });
            await expect(bridge.rescueNative(owner.address)).to.changeEtherBalances([owner, bridge], [amount, -amount]);
        });
    });
    describe("pause", () => {
        it("should revert pause if not owner", async () => {
            const { user, bridge } = await loadFixture(deployBridgeFixture);
            await expect(bridge.connect(user).pause()).to.be.revertedWith("Ownable: caller is not the owner");
        });
        it("should pause", async () => {
            const { owner, bridge } = await loadFixture(deployBridgeFixture);
            await expect(bridge.pause()).to.emit(bridge, "Paused").withArgs(owner.address);
        });
        it("should revert unpause if not owner", async () => {
            const { user, bridge } = await loadFixture(deployBridgeFixture);
            await expect(bridge.connect(user).unpause()).to.be.revertedWith("Ownable: caller is not the owner");
        });
        it("should unpause", async () => {
            const { owner, bridge } = await loadFixture(deployBridgeFixture);
            await bridge.pause();
            await expect(bridge.unpause()).to.emit(bridge, "Unpaused").withArgs(owner.address);
        });
        it("should revert bridgeOut if paused", async () => {
            const { owner, usdcToken, bridge } = await loadFixture(deployBridgeFixture);
            await bridge.pause();
            await expect(
                bridge.bridgeOut(usdcToken.address, 0, 0, addressToBytes32(owner.address), zeroAddress)
            ).to.be.revertedWith("Pausable: paused");
        });
        it("should revert bridgeIn if paused", async () => {
            const { bridge } = await loadFixture(deployBridgeFixture);
            await bridge.pause();
            await expect(bridge.bridgeIn(zeroAddress, zeroAddress)).to.be.revertedWith("Pausable: paused");
        });
    });
    describe("bridgeOut", () => {
        it("should revert if invalid destinationDomain", async () => {
            const { owner, usdcToken, bridge } = await loadFixture(deployBridgeFixture);
            await expect(
                bridge.bridgeOut(usdcToken.address, 0, 0, addressToBytes32(owner.address), zeroAddress)
            ).to.be.revertedWith("target bridge not enabled");
        });
        it("should revert if sender is callProxy", async () => {
            const { owner, usdcToken, bridge, callProxy } = await loadFixture(deployBridgeFixture);
            const callProxyAccount = await getContractAccount(callProxy);
            await bridge.bindBridge(0, addressToBytes32(bridge.address));
            await bridge.setCallProxy(callProxy.address);
            await expect(
                bridge
                    .connect(callProxyAccount)
                    .bridgeOut(usdcToken.address, 0, 0, addressToBytes32(owner.address), zeroAddress)
            ).to.be.revertedWith("forbidden");
        });
        it("should revert if recipient is zeroAddress", async () => {
            const { usdcToken, bridge } = await loadFixture(deployBridgeFixture);
            await bridge.bindBridge(0, addressToBytes32(bridge.address));
            await expect(
                bridge.bridgeOut(usdcToken.address, 0, 0, addressToBytes32(zeroAddress), zeroAddress)
            ).to.be.revertedWith("recipient address cannot be zero");
        });
        it("should revert if token is disabled", async () => {
            const { owner, usdcToken, bridge } = await loadFixture(deployBridgeFixture);
            await bridge.bindBridge(0, addressToBytes32(bridge.address));
            await bridge.disableBridgeToken(usdcToken.address);
            await expect(
                bridge.bridgeOut(usdcToken.address, 0, 0, addressToBytes32(owner.address), zeroAddress)
            ).to.be.revertedWith("token not enabled");
        });
        it("should revert if route is disabled", async () => {
            const { owner, usdcToken, bridge } = await loadFixture(deployBridgeFixture);
            const destinationDomain = 1;

            await bridge.bindBridge(destinationDomain, addressToBytes32(bridge.address));
            await bridge.disableRoute(usdcToken.address, destinationDomain);
            await expect(
                bridge.bridgeOut(usdcToken.address, 0, destinationDomain, addressToBytes32(owner.address), zeroAddress)
            ).to.be.revertedWith("route disabled");
        });
        it("should bridgeOut", async () => {
            const { owner, user, usdcToken, bridge } = await loadFixture(deployBridgeFixture);
            await bridge.bindBridge(0, addressToBytes32(bridge.address));
            await expect(
                bridge
                    .connect(user)
                    .bridgeOut(usdcToken.address, 0, 0, addressToBytes32(owner.address), zeroAddress, { value: 1 })
            )
                .to.changeEtherBalances([user, bridge, owner], [-1, 0, 1])
                .to.be.emit(bridge, "BridgeOut")
                .withArgs(
                    user.address,
                    usdcToken.address,
                    0,
                    0,
                    1,
                    addressToBytes32(owner.address.toLowerCase()),
                    zeroAddress,
                    1
                );
        });
    });
    describe("bridgeIn", () => {
        let args: string;
        beforeEach(async () => {
            const owner = getWalletByIndex(0);
            args = ethers.utils.solidityPack(
                ["bytes", "bytes", "bytes", "bytes", "bytes"],
                [
                    writeVarBytes(zeroAddress),
                    writeVarBytes(owner.address),
                    writeVarBytes(signMessage(owner.address, owner)),
                    writeVarBytes(owner.address),
                    writeVarBytes(emptyString),
                ]
            );
        });
        it("should revert if args length is zero", async () => {
            const { bridge } = await loadFixture(deployBridgeFixture);
            const args = "0x";
            const sig = "0x";
            await expect(bridge.bridgeIn(args, sig)).to.be.revertedWith("invalid bridgeIn args");
        });
        it("should revert if attestation length is zero", async () => {
            const { bridge } = await loadFixture(deployBridgeFixture);
            const sig = "0x";
            await expect(bridge.bridgeIn(args, sig)).to.be.revertedWith("Invalid attestation length");
        });
        it("should revert if invalid attestation length", async () => {
            const { owner, bridge } = await loadFixture(deployBridgeFixture);
            const sig = signMessage(args, owner) + "00";
            await expect(bridge.bridgeIn(args, sig)).to.be.revertedWith("Invalid attestation length");
        });
        it("should revert if invalid signature dupe", async () => {
            const { owner, user, bridge } = await loadFixture(deployBridgeFixture);

            await bridge.enableAttester(user.address);
            await bridge.setSignatureThreshold(2);

            const sig = ethers.utils.solidityPack(["bytes", "bytes"], [signMessage(args, owner), signMessage(args, owner)]);
            await expect(bridge.bridgeIn(args, sig)).to.be.revertedWith("Invalid signature order or dupe");
        });
        it("should revert if invalid signature order", async () => {
            const { owner, user, bridge } = await loadFixture(deployBridgeFixture);

            await bridge.enableAttester(user.address);
            await bridge.setSignatureThreshold(2);

            const sig = ethers.utils.solidityPack(["bytes", "bytes"], [signMessage(args, owner), signMessage(args, user)]);
            await expect(bridge.bridgeIn(args, sig)).to.be.revertedWith("Invalid signature order or dupe");
        });
        it("should revert if invalid signature: not attester", async () => {
            const { user, bridge } = await loadFixture(deployBridgeFixture);

            const sig = signMessage(args, user);
            await expect(bridge.bridgeIn(args, sig)).to.be.revertedWith("Invalid signature: not attester");
        });
        it("should revert if invalid receive message", async () => {
            const { owner, usdcToken, bridge } = await loadFixture(deployBridgeFixture);

            // invalid args.recipient
            const args = ethers.utils.solidityPack(
                ["bytes", "bytes", "bytes", "bytes", "bytes"],
                [
                    writeVarBytes(usdcToken.address),
                    writeVarBytes("0x00"),
                    writeVarBytes(signMessage("0x00", owner)),
                    writeVarBytes(owner.address),
                    writeVarBytes(emptyString),
                ]
            );
            const sig = signMessage(args, owner);
            await expect(bridge.bridgeIn(args, sig)).to.be.revertedWith("bytes length does not match address");
        });
        it("should revert if invalid receive attestation", async () => {
            const { owner, usdcToken, bridge } = await loadFixture(deployBridgeFixture);

            const args = ethers.utils.solidityPack(
                ["bytes", "bytes", "bytes", "bytes", "bytes"],
                [
                    writeVarBytes(usdcToken.address),
                    writeVarBytes(owner.address),
                    writeVarBytes("0x00"),
                    writeVarBytes(owner.address),
                    writeVarBytes(emptyString),
                ]
            );
            const sig = signMessage(args, owner);
            await expect(bridge.bridgeIn(args, sig)).to.be.revertedWith("Invalid attestation length");
        });
        it("should revert if error receiveMessage recipient", async () => {
            const { owner, usdcToken, bridge } = await loadFixture(deployBridgeFixture);

            const args = ethers.utils.solidityPack(
                ["bytes", "bytes", "bytes", "bytes", "bytes"],
                [
                    writeVarBytes(usdcToken.address),
                    writeVarBytes(owner.address),
                    writeVarBytes(signMessage(owner.address, owner)),
                    writeVarBytes(owner.address),
                    writeVarBytes(emptyString),
                ]
            );

            const sig = signMessage(args, owner);
            await expect(bridge.bridgeIn(args, sig)).to.be.revertedWith("amount cannot be zero");
        });
        it("should revert if error bridgeIn recipient", async () => {
            const { owner, usdcToken, bridge } = await loadFixture(deployBridgeFixture);
            const args = ethers.utils.solidityPack(
                ["bytes", "bytes", "bytes", "bytes", "bytes"],
                [
                    writeVarBytes(usdcToken.address),
                    writeVarBytes(bridge.address),
                    writeVarBytes(signMessage(bridge.address, owner)),
                    writeVarBytes(zeroAddress),
                    writeVarBytes(emptyString),
                ]
            );

            const sig = signMessage(args, owner);
            await expect(bridge.bridgeIn(args, sig)).to.be.revertedWith("recipient address cannot be zero");
        });
        it("should bridgeIn and send if not set callProxy", async () => {
            const { owner, bridge, usdcToken } = await loadFixture(deployBridgeFixture);
            const amount = 10;
            const args = ethers.utils.solidityPack(
                ["bytes", "bytes", "bytes", "bytes", "bytes"],
                [
                    writeVarBytes(usdcToken.address),
                    writeVarBytes(bridge.address),
                    writeVarBytes(signMessage(bridge.address, owner)),
                    writeVarBytes(owner.address),
                    writeVarBytes(emptyString),
                ]
            );
            const sig = signMessage(args, owner);
            await expect(bridge.bridgeIn(args, sig))
                .to.emit(bridge, "BridgeIn")
                .withArgs(owner.address, owner.address, usdcToken.address, amount)
                .to.emit(usdcToken, "Transfer")
                .withArgs(bridge.address, owner.address, amount);
        });
    });
    describe("bridgeInAndProxyCall", () => {
        it("should bridgeIn and send if invalid calldata", async () => {
            const { bridge, callProxy, owner, user, usdcToken, usdtToken, mockPool } = await loadFixture(
                deployBridgeFixture
            );
            const amount = 10;
            await bridge.setCallProxy(callProxy.address);
            const poolCalldata = mockPool.interface.encodeFunctionData("swap", [
                usdcToken.address,
                usdtToken.address,
                amount / 2,
                user.address,
            ]);
            const calldata = await callProxy.encodeCallDataForExternalCall(mockPool.address, poolCalldata);
            const args = ethers.utils.solidityPack(
                ["bytes", "bytes", "bytes", "bytes", "bytes"],
                [
                    writeVarBytes(usdcToken.address),
                    writeVarBytes(bridge.address),
                    writeVarBytes(signMessage(bridge.address, owner)),
                    writeVarBytes(owner.address),
                    writeVarBytes(calldata),
                ]
            );

            const sig = signMessage(args, owner);
            // bridge -10-> callProxy -5-> mockPool -10-> user
            //              callProxy -5-> owner
            await expect(bridge.bridgeIn(args, sig))
                .to.emit(bridge, "BridgeIn")
                .withArgs(owner.address, owner.address, usdcToken.address, amount)
                .to.emit(usdcToken, "Transfer")
                .withArgs(bridge.address, callProxy.address, amount)
                .to.emit(usdcToken, "Transfer")
                .withArgs(callProxy.address, mockPool.address, amount / 2)
                .to.emit(usdtToken, "Transfer")
                .withArgs(mockPool.address, user.address, (amount / 2) * 2)
                .to.emit(usdcToken, "Transfer")
                .withArgs(callProxy.address, owner.address, amount / 2);
        });
    });
    describe("externalCall", () => {
        it("should revert if not owner", async () => {
            const { user, bridge } = await loadFixture(deployBridgeFixture);
            await expect(bridge.connect(user).externalCall(bridge.address, zeroAddress)).to.be.revertedWith(
                "Ownable: caller is not the owner"
            );
        });
        it("should call receiveMessage", async () => {
            const { owner, bridge, usdcToken, mockMessageTransmitter } = await loadFixture(deployBridgeFixture);
            const amount = 10;
            const calldata = mockMessageTransmitter.interface.encodeFunctionData("receiveMessage", [
                owner.address,
                signMessage(owner.address, owner),
            ]);

            await expect(bridge.externalCall(mockMessageTransmitter.address, calldata))
                .to.emit(usdcToken, "Transfer")
                .withArgs(mockMessageTransmitter.address, owner.address, amount);
        });
    });
});
