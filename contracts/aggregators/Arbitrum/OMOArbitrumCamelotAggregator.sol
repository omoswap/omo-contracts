// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import "../../access/Ownable.sol";
import "../../interfaces/IBridge.sol";
import "../../assets/interfaces/IWETH.sol";
import "./libraries/ArbitrumCamelotLibrary.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract OMOArbitrumCamelotAggregator is Ownable {
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

    address public WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public factory = 0x6EcCab422D763aC031210895C81787E87B43A652;
    address public bridge = 0xa39628ee6Ca80eb2D93f21Def75A7B4D03b82e1E;
    address public feeCollector;

    uint256 public aggregatorFee = 3 * 10 ** 7;
    uint256 public constant FEE_DENOMINATOR = 10 ** 10;
    uint256 private constant MAX_AGGREGATOR_FEE = 5 * 10**8;

    constructor (address _feeCollector) {
        require(_feeCollector != address(0), "feeCollector address cannot be zero");
        feeCollector = _feeCollector;
    }

    receive() external payable { }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        address[] calldata path,
        address to,
        uint amountOutMin,
        bool unwrapETH
    ) external {
        if (amountIn == 0) {
            require(msg.sender == IBridge(bridge).callProxy(), "invalid caller");
            amountIn = IERC20(path[0]).allowance(msg.sender, address(this));
        }
        require(amountIn != 0, 'OMOAggregator: ZERO_AMOUNT_IN');

        uint amountOut = _swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn, amountOutMin, path);
        uint feeAmount = amountOut * aggregatorFee / FEE_DENOMINATOR;
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
        uint amountIn, uint amountOutMin, address[] calldata path,         // args for dex
        uint32 destinationDomain, bytes32 recipient, bytes calldata callData // args for bridge
    ) external payable {
        uint amountOut = _swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn, amountOutMin, path);
        uint feeAmount = amountOut * aggregatorFee / FEE_DENOMINATOR;
        address bridgeToken = path[path.length-1];
        IERC20(bridgeToken).safeTransfer(feeCollector, feeAmount);
        emit LOG_AGG_SWAP(msg.sender, amountIn, path[0], amountOut, bridgeToken, msg.sender, feeAmount);

        uint bridgeAmount = amountOut - feeAmount;

        IERC20(bridgeToken).safeApprove(bridge, bridgeAmount);

        IBridge(bridge).bridgeOut{value: msg.value}(
            bridgeToken, bridgeAmount, destinationDomain, recipient, callData
        );
    }

    function _swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn, uint amountOutMin, address[] calldata path
    ) internal returns (uint) {
        IERC20(path[0]).safeTransferFrom(
            msg.sender, ArbitrumCamelotLibrary.pairFor(factory, path[0], path[1]), amountIn
        );

        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(address(this));
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20(path[path.length - 1]).balanceOf(address(this)) - balanceBefore;

        require(amountOut >= amountOutMin, 'OMOAggregator: INSUFFICIENT_OUTPUT_AMOUNT');

        return amountOut;
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin, address[] calldata path, address to
    ) external payable {
        uint amountOut = _swapExactETHForTokensSupportingFeeOnTransferTokens(amountOutMin, path, 0);
        uint feeAmount = amountOut * aggregatorFee / FEE_DENOMINATOR;
        emit LOG_AGG_SWAP(msg.sender, msg.value, address(0), amountOut, path[path.length-1], to, feeAmount);

        IERC20(path[path.length-1]).safeTransfer(feeCollector, feeAmount);
        IERC20(path[path.length - 1]).safeTransfer(to, amountOut - feeAmount);
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokensCrossChain(
        uint amountOutMin, address[] calldata path, uint netFee,            // args for dex
        uint32 destinationDomain, bytes32 recipient, bytes calldata callData // args for bridge
    ) external payable {
        uint amountOut = _swapExactETHForTokensSupportingFeeOnTransferTokens(amountOutMin, path, netFee);
        uint feeAmount = amountOut * aggregatorFee / FEE_DENOMINATOR;
        address bridgeToken = path[path.length-1];
        IERC20(bridgeToken).safeTransfer(feeCollector, feeAmount);
        emit LOG_AGG_SWAP(msg.sender, msg.value-netFee, address(0), amountOut, bridgeToken, msg.sender, feeAmount);

        uint bridgeAmount = amountOut - feeAmount;

        IERC20(bridgeToken).safeApprove(bridge, bridgeAmount);

        IBridge(bridge).bridgeOut{value: netFee}(
            bridgeToken, bridgeAmount, destinationDomain, recipient, callData
        );
    }

    function _swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint swapAmountOutMin, address[] calldata path, uint netFee
    ) internal returns (uint) {
        require(path[0] == WETH, 'OMOAggregator: INVALID_PATH');

        uint amountIn = msg.value - netFee;
        require(amountIn > 0, 'OMOAggregator: INSUFFICIENT_INPUT_AMOUNT');

        IWETH(WETH).deposit{value: amountIn}();
        assert(IWETH(WETH).transfer(ArbitrumCamelotLibrary.pairFor(factory, path[0], path[1]), amountIn));

        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(address(this));
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20(path[path.length - 1]).balanceOf(address(this)) - balanceBefore;
        require(amountOut >= swapAmountOutMin, 'OMOAggregator: INSUFFICIENT_OUTPUT_AMOUNT');

        return amountOut;
    }

    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = ArbitrumCamelotLibrary.sortTokens(input, output);
            IArbitrumCamelotPair pair = IArbitrumCamelotPair(ArbitrumCamelotLibrary.pairFor(factory, input, output));
            uint amountOutput;
            {// scope to avoid stack too deep errors
                (uint reserve0, uint reserve1,,) = pair.getReserves();
                // permute values to force reserve0 == inputReserve
                if (input != token0) (reserve0, reserve1) = (reserve1, reserve0);
                uint amountInput = IERC20(input).balanceOf(address(pair)) - reserve0;
                amountOutput = pair.getAmountOut(amountInput, input);
            }

            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2 ? ArbitrumCamelotLibrary.pairFor(factory, output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0), feeCollector);
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

    function setAggregatorFee(uint _fee) external onlyOwner {
        require(_fee < MAX_AGGREGATOR_FEE, "aggregator fee exceeds maximum");
        aggregatorFee = _fee;
    }

    function rescueFund(address tokenAddress) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        if (tokenAddress == WETH && address(this).balance > 0) {
            _sendETH(msg.sender, address(this).balance);
        }
        token.safeTransfer(msg.sender, token.balanceOf(address(this)));
    }
}
