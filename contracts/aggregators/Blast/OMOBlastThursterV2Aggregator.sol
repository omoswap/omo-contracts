// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import "./interfaces/IBlast.sol";
import "../../access/Ownable.sol";
import "../../interfaces/IBridge.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../../assets/interfaces/IWETH.sol";
import "./libraries/BlastThursterV2Library.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract OMOBlastThursterV2Aggregator is Ownable {
    using SafeERC20 for IERC20;

    event LOG_AGG_SWAP (
        address caller,
        uint256 amountIn,
        address tokenIn,
        uint256 amountOut,
        address tokenOut,
        address receiver,
        uint256 fee
    );

    address public WETH = 0x4300000000000000000000000000000000000004;
    address public factory = 0xb4A7D971D0ADea1c73198C97d7ab3f9CE4aaFA13;
    address public bridge = 0x0000000000000000000000000000000000000000;
    address public feeCollector;

    uint256 public aggregatorFee = 3 * 10 ** 7;
    uint256 public constant FEE_DENOMINATOR = 10 ** 10;
    uint256 private constant MAX_AGGREGATOR_FEE = 5 * 10**8;

    IBlast private constant BLAST = IBlast(0x4300000000000000000000000000000000000002);
    IBlastPoints private constant BLAST_POINTS = IBlastPoints(0x2536FE9ab3F511540F2f9e2eC2A805005C3Dd800);

    constructor (address _feeCollector) {
        require(_feeCollector != address(0), "feeCollector address cannot be zero");
        feeCollector = _feeCollector;

        BLAST.configureClaimableGas();
        BLAST.configureGovernor(_feeCollector);
        BLAST_POINTS.configurePointsOperator(_feeCollector);
    }

    receive() external payable { }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        address[] calldata path,
        address to,
        uint256 amountOutMin,
        bool unwrapETH
    ) external {
        if (amountIn == 0) {
            require(msg.sender == IBridge(bridge).callProxy(), "invalid caller");
            amountIn = IERC20(path[0]).allowance(msg.sender, address(this));
        }
        require(amountIn != 0, 'OMOAggregator: ZERO_AMOUNT_IN');

        uint256 amountOut = _swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn, amountOutMin, path);
        uint256 feeAmount = amountOut * aggregatorFee / FEE_DENOMINATOR;
        address toToken = path[path.length-1];

        if (unwrapETH) {
            require(toToken == WETH, "OMOAggregator: INVALID_PATH");
            IWETH(WETH).withdraw(amountOut);
            _sendETH(feeCollector, feeAmount);
            _sendETH(to, amountOut - feeAmount);
            toToken = address(0);
        } else {
            IERC20(toToken).safeTransfer(feeCollector, feeAmount);
            IERC20(toToken).safeTransfer(to, amountOut - feeAmount);
        }

        emit LOG_AGG_SWAP(msg.sender, amountIn, path[0], amountOut, toToken, to, feeAmount);
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokensCrossChain(
        uint256 amountIn, uint256 amountOutMin, address[] calldata path,     // args for dex
        uint32 destinationDomain, bytes32 recipient, bytes calldata callData // args for bridge
    ) external payable {
        uint256 amountOut = _swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn, amountOutMin, path);
        uint256 feeAmount = amountOut * aggregatorFee / FEE_DENOMINATOR;
        address bridgeToken = path[path.length-1];
        IERC20(bridgeToken).safeTransfer(feeCollector, feeAmount);
        emit LOG_AGG_SWAP(msg.sender, amountIn, path[0], amountOut, bridgeToken, msg.sender, feeAmount);

        uint256 bridgeAmount = amountOut - feeAmount;

        IERC20(bridgeToken).safeApprove(bridge, bridgeAmount);

        IBridge(bridge).bridgeOut{value: msg.value}(
            bridgeToken, bridgeAmount, destinationDomain, recipient, callData
        );
    }

    function _swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn, uint256 amountOutMin, address[] calldata path
    ) internal returns (uint256) {
        IERC20(path[0]).safeTransferFrom(
            msg.sender, BlastThursterV2Library.pairFor(factory, path[0], path[1]), amountIn
        );

        uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(address(this));
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint256 amountOut = IERC20(path[path.length - 1]).balanceOf(address(this)) - balanceBefore;

        require(amountOut >= amountOutMin, 'OMOAggregator: INSUFFICIENT_OUTPUT_AMOUNT');

        return amountOut;
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin, address[] calldata path, address to
    ) external payable {
        uint256 amountOut = _swapExactETHForTokensSupportingFeeOnTransferTokens(amountOutMin, path, 0);
        uint256 feeAmount = amountOut * aggregatorFee / FEE_DENOMINATOR;
        emit LOG_AGG_SWAP(msg.sender, msg.value, address(0), amountOut, path[path.length-1], to, feeAmount);

        IERC20(path[path.length-1]).safeTransfer(feeCollector, feeAmount);
        IERC20(path[path.length - 1]).safeTransfer(to, amountOut - feeAmount);
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokensCrossChain(
        uint256 amountOutMin, address[] calldata path, uint256 netFee,       // args for dex
        uint32 destinationDomain, bytes32 recipient, bytes calldata callData // args for bridge
    ) external payable {
        uint256 amountOut = _swapExactETHForTokensSupportingFeeOnTransferTokens(amountOutMin, path, netFee);
        uint256 feeAmount = amountOut * aggregatorFee / FEE_DENOMINATOR;
        address bridgeToken = path[path.length-1];
        IERC20(bridgeToken).safeTransfer(feeCollector, feeAmount);
        emit LOG_AGG_SWAP(msg.sender, msg.value-netFee, address(0), amountOut, bridgeToken, msg.sender, feeAmount);

        uint256 bridgeAmount = amountOut - feeAmount;

        IERC20(bridgeToken).safeApprove(bridge, bridgeAmount);

        IBridge(bridge).bridgeOut{value: netFee}(
            bridgeToken, bridgeAmount, destinationDomain, recipient, callData
        );
    }

    function _swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 swapAmountOutMin, address[] calldata path, uint256 netFee
    ) internal returns (uint256) {
        require(path[0] == WETH, 'OMOAggregator: INVALID_PATH');

        uint256 amountIn = msg.value - netFee;
        require(amountIn > 0, 'OMOAggregator: INSUFFICIENT_INPUT_AMOUNT');

        IWETH(WETH).deposit{value: amountIn}();
        assert(IWETH(WETH).transfer(BlastThursterV2Library.pairFor(factory, path[0], path[1]), amountIn));

        uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(address(this));
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint256 amountOut = IERC20(path[path.length - 1]).balanceOf(address(this)) - balanceBefore;
        require(amountOut >= swapAmountOutMin, 'OMOAggregator: INSUFFICIENT_OUTPUT_AMOUNT');

        return amountOut;
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = BlastThursterV2Library.sortTokens(input, output);
            IUniswapV2Pair pair = IUniswapV2Pair(BlastThursterV2Library.pairFor(factory, input, output));
            uint256 amountInput;
            uint256 amountOutput;
            { // scope to avoid stack too deep errors
                (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
                (uint256 reserveInput, uint256 reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                amountInput = IERC20(input).balanceOf(address(pair)) - reserveInput;
                amountOutput = BlastThursterV2Library.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            (uint256 amount0Out, uint256 amount1Out) = input == token0 ? (uint256(0), amountOutput) : (amountOutput, uint256(0));
            address to = i < path.length - 2 ? BlastThursterV2Library.pairFor(factory, output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function _sendETH(address to, uint256 amount) internal {
        (bool success,) = to.call{value:amount}(new bytes(0));
        require(success, 'OMOAggregator: ETH_TRANSFER_FAILED');
    }

    function setWETH(address _weth) external onlyOwner {
        WETH = _weth;
    }

    function setFactory(address _factory) external onlyOwner {
        require(_factory != address(0), "factory address cannot be zero");
        factory = _factory;
    }

    function setBridge(address _bridge) external onlyOwner {
        require(_bridge != address(0), "bridge address cannot be zero");
        bridge = _bridge;
    }

    function setFeeCollector(address _feeCollector) external onlyOwner {
        feeCollector = _feeCollector;
    }

    function setAggregatorFee(uint256 _fee) external onlyOwner {
        require(_fee < MAX_AGGREGATOR_FEE, "aggregator fee exceeds maximum");
        aggregatorFee = _fee;
    }

    function externalCall(
        address callee, bytes calldata callData
    ) external onlyOwner returns (bytes memory) {
        (bool success, bytes memory data) = callee.call(callData);
        require(success, "external call failed");
        return data;
    }

    function rescueFund(address tokenAddress) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        if (tokenAddress == WETH && address(this).balance > 0) {
            _sendETH(msg.sender, address(this).balance);
        }
        token.safeTransfer(msg.sender, token.balanceOf(address(this)));
    }
}
