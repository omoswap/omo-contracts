import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { deployAggregatorFixture } from "./utils/fixtures";
import { addressToBytes32, getContractAccount, zeroAddress } from "./utils/utilities";

// MockUniswapV2Pair code hash badcace35eca3975b86a7d744a198f996983b3f8f265644b0c0db50289070a24

describe("OMOEthereumUniswapAggregator", function () {
    describe("TokenForTokens", function () {
        it("should revert if amountIn is zero and bridge unset", async function () {
            const { owner, user, path } = await loadFixture(deployAggregatorFixture);

            const OMOEthereumUniswapAggregatorFactory = await ethers.getContractFactory("OMOEthereumUniswapAggregator");
            const OMOEthereumUniswapAggregator = await OMOEthereumUniswapAggregatorFactory.deploy(owner.address);

            await expect(
                OMOEthereumUniswapAggregator.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    0,
                    path,
                    user.address,
                    1,
                    false
                )
            ).to.be.revertedWithoutReason();
        });
        it("should revert if amountIn is zero and sender not is callProxy", async function () {
            const { user, path, bridge, OMOEthereumUniswapAggregator } = await loadFixture(deployAggregatorFixture);

            await OMOEthereumUniswapAggregator.setBridge(bridge.address);

            await expect(
                OMOEthereumUniswapAggregator.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    0,
                    path,
                    user.address,
                    1,
                    false
                )
            ).to.be.revertedWith("invalid caller");
        });
        it("should revert if amountIn is zero and sender not approve token", async function () {
            const { user, path, callProxy, OMOEthereumUniswapAggregator } = await loadFixture(deployAggregatorFixture);
            const callProxyAccount = await getContractAccount(callProxy);

            await expect(
                OMOEthereumUniswapAggregator.connect(callProxyAccount).swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    0,
                    path,
                    user.address,
                    1,
                    false
                )
            ).to.be.revertedWith("OMOAggregator: ZERO_AMOUNT_IN");
        });
        it("should revert if path include same token", async function () {
            const { user, tokenA, tokenB, OMOEthereumUniswapAggregator } = await loadFixture(deployAggregatorFixture);

            await expect(
                OMOEthereumUniswapAggregator.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    10,
                    [tokenA.address, tokenB.address, tokenB.address],
                    user.address,
                    100,
                    false
                )
            ).revertedWith("UniswapV2Library: IDENTICAL_ADDRESSES");
        });
        it("should revert if path include zeroAddress token", async function () {
            const { user, tokenA, OMOEthereumUniswapAggregator } = await loadFixture(deployAggregatorFixture);

            await expect(
                OMOEthereumUniswapAggregator.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    10,
                    [tokenA.address, zeroAddress],
                    user.address,
                    100,
                    false
                )
            ).revertedWith("UniswapV2Library: ZERO_ADDRESS");
        });
        it("should revert if path[path.length-1] zeroAddress token", async function () {
            const { user, tokenA, tokenB, OMOEthereumUniswapAggregator } = await loadFixture(deployAggregatorFixture);

            await expect(
                OMOEthereumUniswapAggregator.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    10,
                    [tokenA.address, tokenB.address, zeroAddress],
                    user.address,
                    100,
                    false
                )
            ).revertedWithoutReason();
        });
        it("should revert if amountOut is less than amountOutMin", async function () {
            const { user, path, OMOEthereumUniswapAggregator } = await loadFixture(deployAggregatorFixture);

            await expect(
                OMOEthereumUniswapAggregator.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    10,
                    path,
                    user.address,
                    100,
                    false
                )
            ).revertedWith("OMOAggregator: INSUFFICIENT_OUTPUT_AMOUNT");
        });
        it("should swap", async function () {
            const {
                owner,
                user,
                tokenA,
                tokenB,
                tokenC,
                OMOEthereumUniswapAggregator,
                mockUniswapV2PairAB,
                mockUniswapV2PairBC,
            } = await loadFixture(deployAggregatorFixture);

            // owner               -10 tokenA -> mockUniswapV2PairAB
            // mockUniswapV2PairAB -20 tokenB -> mockUniswapV2PairBC
            // mockUniswapV2PairBC -40 tokenC -> user
            await expect(
                OMOEthereumUniswapAggregator.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    10,
                    [tokenA.address, tokenB.address, tokenC.address],
                    user.address,
                    10,
                    false
                )
            )
                .to.changeTokenBalances(tokenA, [owner, mockUniswapV2PairAB], [-10, 10])
                .to.changeTokenBalances(tokenB, [mockUniswapV2PairAB, mockUniswapV2PairBC], [-20, 20])
                .to.changeTokenBalances(tokenC, [mockUniswapV2PairBC, user], [-40, 40]);
        });
    });

    describe("TokenForTokensCrossChain", function () {
        it("should swap and crossChain", async function () {
            const {
                owner,
                user,
                tokenA,
                tokenB,
                tokenC,
                OMOEthereumUniswapAggregator,
                mockUniswapV2PairAB,
                mockUniswapV2PairBC,
                bridge,
            } = await loadFixture(deployAggregatorFixture);

            // owner               -10 tokenA -> mockUniswapV2PairAB
            // mockUniswapV2PairAB -20 tokenB -> mockUniswapV2PairBC
            // mockUniswapV2PairBC -1  tokenC -> fee
            // mockUniswapV2PairBC -39 tokenC -> bridge
            await OMOEthereumUniswapAggregator.setAggregatorFee(4.5 * 10 ** 8);

            await expect(
                OMOEthereumUniswapAggregator.swapExactTokensForTokensSupportingFeeOnTransferTokensCrossChain(
                    10,
                    10,
                    [tokenA.address, tokenB.address, tokenC.address],
                    1,
                    user.address,
                    zeroAddress
                )
            )
                .to.changeTokenBalances(tokenA, [owner, mockUniswapV2PairAB], [-10, 10])
                .to.changeTokenBalances(tokenB, [mockUniswapV2PairAB, mockUniswapV2PairBC], [-20, 20])
                .to.changeTokenBalances(tokenC, [mockUniswapV2PairBC, bridge], [-40, 39])
                .to.be.emit(bridge, "BridgeOut")
                .withArgs(
                    OMOEthereumUniswapAggregator.address,
                    tokenC.address,
                    1,
                    39,
                    1,
                    addressToBytes32(user.address.toLowerCase()),
                    zeroAddress,
                    0
                );
        });
    });

    describe("ETHForTokens", function () {
        it("should revert if path not startWith WETH", async function () {
            const { user, path, OMOEthereumUniswapAggregator } = await loadFixture(deployAggregatorFixture);

            await expect(
                OMOEthereumUniswapAggregator.swapExactETHForTokensSupportingFeeOnTransferTokens(10, path, user.address, {
                    value: 10,
                })
            ).revertedWith("OMOAggregator: INVALID_PATH");
        });
        it("should revert if amountOut is less than amountOutMin", async function () {
            const { user, WETH, path, OMOEthereumUniswapAggregator } = await loadFixture(deployAggregatorFixture);

            await expect(
                OMOEthereumUniswapAggregator.swapExactETHForTokensSupportingFeeOnTransferTokens(
                    10000,
                    [WETH.address, ...path],
                    user.address,
                    {
                        value: 10,
                    }
                )
            ).revertedWith("OMOAggregator: INSUFFICIENT_OUTPUT_AMOUNT");
        });
        it("should swap", async function () {
            const {
                owner,
                user,
                WETH,
                tokenA,
                tokenB,
                tokenC,
                OMOEthereumUniswapAggregator,
                mockUniswapV2PairAB,
                mockUniswapV2PairBC,
            } = await loadFixture(deployAggregatorFixture);

            // owner                 -5  eth    -> mockUniswapV2PairWTHA
            // mockUniswapV2PairWTHA -10 tokenA -> mockUniswapV2PairAB
            // mockUniswapV2PairAB   -20 tokenB -> mockUniswapV2PairBC
            // mockUniswapV2PairBC   -40 tokenC -> user
            // minOut = 39
            await expect(
                OMOEthereumUniswapAggregator.swapExactETHForTokensSupportingFeeOnTransferTokens(
                    39,
                    [WETH.address, tokenA.address, tokenB.address, tokenC.address],
                    user.address,
                    {
                        value: 5,
                    }
                )
            )
                .to.changeEtherBalances([owner, mockUniswapV2PairAB], [-5, 5])
                .to.changeTokenBalances(tokenA, [owner, mockUniswapV2PairAB], [-10, 10])
                .to.changeTokenBalances(tokenB, [mockUniswapV2PairAB, mockUniswapV2PairBC], [-20, 20])
                .to.changeTokenBalances(tokenC, [mockUniswapV2PairBC, user], [-40, 40]);
        });
    });

    describe("ETHForTokensCrossChain", function () {
        it("should revert if value less than netfee", async function () {
            const { user, WETH, path, OMOEthereumUniswapAggregator } = await loadFixture(deployAggregatorFixture);

            await expect(
                OMOEthereumUniswapAggregator.swapExactETHForTokensSupportingFeeOnTransferTokensCrossChain(
                    39,
                    [WETH.address, ...path],
                    1,
                    100,
                    user.address,
                    zeroAddress,
                    {
                        value: 5,
                    }
                )
            ).to.be.revertedWith("OMOAggregator: INSUFFICIENT_OUTPUT_AMOUNT");
        });
        it("should swap", async function () {
            const {
                owner,
                user,
                WETH,
                tokenA,
                tokenB,
                tokenC,
                OMOEthereumUniswapAggregator,
                mockUniswapV2PairAB,
                mockUniswapV2PairBC,
                bridge,
            } = await loadFixture(deployAggregatorFixture);

            // owner                 -5  eth    -> mockUniswapV2PairWTHA
            // mockUniswapV2PairWTHA -10 tokenA -> mockUniswapV2PairAB
            // mockUniswapV2PairAB   -20 tokenB -> mockUniswapV2PairBC
            // mockUniswapV2PairBC   -40 tokenC -> user
            // minOut = 39
            await expect(
                OMOEthereumUniswapAggregator.swapExactETHForTokensSupportingFeeOnTransferTokensCrossChain(
                    30,
                    [WETH.address, tokenA.address, tokenB.address, tokenC.address],
                    1,
                    1,
                    user.address,
                    zeroAddress,
                    {
                        value: 6,
                    }
                )
            )
                .to.changeEtherBalances([owner, mockUniswapV2PairAB], [-5, 5])
                .to.changeTokenBalances(tokenA, [owner, mockUniswapV2PairAB], [-10, 10])
                .to.changeTokenBalances(tokenB, [mockUniswapV2PairAB, mockUniswapV2PairBC], [-20, 20])
                .to.changeTokenBalances(tokenC, [mockUniswapV2PairBC, bridge], [-40, 40])
                .to.be.emit(bridge, "BridgeOut")
                .withArgs(
                    OMOEthereumUniswapAggregator.address,
                    tokenC.address,
                    1,
                    40,
                    1,
                    addressToBytes32(user.address.toLowerCase()),
                    zeroAddress,
                    1
                );
        });
    });
});
