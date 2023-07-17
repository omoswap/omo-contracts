import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { deployBridgeFixture } from "./utils/fixtures";
import { zeroAddress } from "./utils/utilities";

describe("callProxy", () => {
    describe("setBridge", () => {
        it("should revert set bridge if not owner", async () => {
            const { user, bridge, callProxy } = await loadFixture(deployBridgeFixture);
            await expect(callProxy.connect(user).setBridge(bridge.address)).to.be.revertedWith(
                "Ownable: caller is not the owner"
            );
        });
        it("should revert set bridge if bridge address is zero", async () => {
            const { callProxy } = await loadFixture(deployBridgeFixture);
            await expect(callProxy.setBridge(zeroAddress)).to.be.revertedWith("bridge address cannot be zero");
        });
        it("should set bridge", async () => {
            const { bridge, callProxy } = await loadFixture(deployBridgeFixture);
            await expect(callProxy.setBridge(bridge.address)).to.emit(callProxy, "SetBridge").withArgs(bridge.address);

            expect(await callProxy.bridge()).to.be.equal(bridge.address);
        });
    });
    describe("calldata", () => {
        it("should encode and decode calldata", async () => {
            const { callProxy, usdcToken } = await loadFixture(deployBridgeFixture);
            const calldata = await callProxy.encodeCallDataForExternalCall(usdcToken.address, zeroAddress);

            expect(await callProxy.decodeCallDataForExternalCall(calldata)).to.be.deep.equal([
                usdcToken.address,
                zeroAddress,
            ]);
        });
    });
    describe("rescue", () => {
        it("should revert rescueFund if not owner", async () => {
            const { user, callProxy, usdcToken } = await loadFixture(deployBridgeFixture);
            await expect(callProxy.connect(user).rescueFund(usdcToken.address)).to.be.revertedWith(
                "Ownable: caller is not the owner"
            );
        });
        it("should rescueFund", async () => {
            const { owner, callProxy, usdcToken } = await loadFixture(deployBridgeFixture);
            const amount = 10;
            await usdcToken.transfer(callProxy.address, amount);

            await expect(callProxy.rescueFund(usdcToken.address)).to.changeTokenBalances(
                usdcToken,
                [owner, callProxy],
                [amount, -amount]
            );
        });
    });
    describe("proxyCall", () => {
        it("should revert proxyCall if not bridge", async () => {
            const { callProxy, usdcToken } = await loadFixture(deployBridgeFixture);
            await expect(callProxy.proxyCall(usdcToken.address, 0, zeroAddress, zeroAddress)).to.be.revertedWith(
                "CallProxy: no privilege"
            );
        });
        it("should receive token if invalid calldata", async () => {
            const { callProxy, owner, user, usdcToken, mockPool } = await loadFixture(deployBridgeFixture);
            await callProxy.setBridge(owner.address);
            const calldata = await callProxy.encodeCallDataForExternalCall(mockPool.address, zeroAddress);
            const amount = 1;
            usdcToken.transfer(callProxy.address, amount);

            // callProxy -1-> user
            await expect(callProxy.proxyCall(usdcToken.address, amount, user.address, calldata))
                .to.emit(usdcToken, "Transfer")
                .withArgs(callProxy.address, user.address, amount);
        });
        it("should receive token and call if not all token used", async () => {
            const { callProxy, owner, user, usdcToken, usdtToken, mockPool } = await loadFixture(deployBridgeFixture);
            await callProxy.setBridge(owner.address);

            const amount = 10;
            usdcToken.transfer(callProxy.address, amount);

            const poolCalldata = mockPool.interface.encodeFunctionData("swap", [
                usdcToken.address,
                usdtToken.address,
                amount / 2,
                user.address,
            ]);
            const calldata = await callProxy.encodeCallDataForExternalCall(mockPool.address, poolCalldata);

            // callProxy -5-> user
            //           -5-> pool -10-> user
            await expect(callProxy.proxyCall(usdcToken.address, amount, user.address, calldata))
                .to.emit(usdcToken, "Transfer")
                .withArgs(callProxy.address, user.address, amount / 2)
                .to.emit(usdcToken, "Transfer")
                .withArgs(callProxy.address, mockPool.address, amount / 2)
                .to.emit(usdtToken, "Transfer")
                .withArgs(mockPool.address, user.address, amount);
        });
        it("should proxyCall", async () => {
            const { callProxy, owner, user, usdcToken, usdtToken, mockPool } = await loadFixture(deployBridgeFixture);
            await callProxy.setBridge(owner.address);

            const amount = 10;
            usdcToken.transfer(callProxy.address, amount);

            const poolCalldata = mockPool.interface.encodeFunctionData("swap", [
                usdcToken.address,
                usdtToken.address,
                amount,
                user.address,
            ]);
            const calldata = await callProxy.encodeCallDataForExternalCall(mockPool.address, poolCalldata);

            // callProxy -10-> pool -20-> user
            await expect(callProxy.proxyCall(usdcToken.address, amount, user.address, calldata))
                .to.emit(usdcToken, "Transfer")
                .withArgs(callProxy.address, mockPool.address, amount)
                .to.emit(usdtToken, "Transfer")
                .withArgs(mockPool.address, user.address, amount * 2);
        });
    });
});
