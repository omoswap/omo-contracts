// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import "../../access/Ownable.sol";
import "../../interfaces/IBridge.sol";
import "../../assets/interfaces/IWETH.sol";
import "../interfaces/ILBRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract OMOMantleMerchantMoeAggregator is Ownable {
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

    address public WETH = 0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8;
    address public router = 0xAFb85a12Babfafabfe1a518594492d5a830e782a;
    address public bridge = 0x0000000000000000000000000000000000000000;
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
        uint amountIn, uint amountOutMin,
        ILBRouter.Path calldata path,
        address receiver, bool unwrapETH
    ) external {
        if (amountIn == 0) {
            require(msg.sender == IBridge(bridge).callProxy(), "OMOAggregator: INVALID_CALLER");
            amountIn = path.tokenPath[0].allowance(msg.sender, address(this));
        }
        require(amountIn != 0, 'OMOAggregator: ZERO_AMOUNT_IN');

        IERC20 tokenOut = path.tokenPath[path.tokenPath.length-1];
        uint256 balanceBefore = tokenOut.balanceOf(address(this));
        path.tokenPath[0].safeTransferFrom(msg.sender, address(this), amountIn);

        uint amountOutCharged = _swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn, amountOutMin, path, balanceBefore, false, unwrapETH, receiver
        );

        if (unwrapETH) {
            require(address(tokenOut) == WETH, "OMOAggregator: INVALID_TOKEN_OUT");
            IWETH(WETH).withdraw(amountOutCharged);
            _sendETH(receiver, amountOutCharged);
        } else {
            tokenOut.safeTransfer(receiver, amountOutCharged);
        }
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokensCrossChain(
        uint amountIn, uint amountOutMin, ILBRouter.Path calldata path, // args for dex
        uint32 destinationDomain, bytes32 recipient, bytes calldata callData // args for bridge
    ) external payable {
        address bridgeToken = address(path.tokenPath[path.tokenPath.length-1]);
        uint256 balanceBefore = IERC20(bridgeToken).balanceOf(address(this));
        path.tokenPath[0].safeTransferFrom(msg.sender, address(this), amountIn);

        uint bridgeAmount = _swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn, amountOutMin, path, balanceBefore, false, false, msg.sender
        );

        IERC20(bridgeToken).safeApprove(bridge, bridgeAmount);
        IBridge(bridge).bridgeOut{value: msg.value}(bridgeToken, bridgeAmount, destinationDomain, recipient, callData);
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        ILBRouter.Path calldata path,
        address receiver
    ) external payable {
        uint amountOutCharged = _swapExactETHForTokensSupportingFeeOnTransferTokens(
            amountOutMin, path, 0, receiver
        );

        IERC20 tokenOut = path.tokenPath[path.tokenPath.length-1];
        tokenOut.safeTransfer(receiver, amountOutCharged);
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokensCrossChain(
        uint amountOutMin, ILBRouter.Path calldata path, uint netFee, // args for dex
        uint32 destinationDomain, bytes32 recipient, bytes calldata callData // args for bridge
    ) external payable {
        uint bridgeAmount = _swapExactETHForTokensSupportingFeeOnTransferTokens(
            amountOutMin, path, netFee, msg.sender
        );

        address bridgeToken = address(path.tokenPath[path.tokenPath.length-1]);
        IERC20(bridgeToken).safeApprove(bridge, bridgeAmount);
        IBridge(bridge).bridgeOut{value: netFee}(bridgeToken, bridgeAmount, destinationDomain, recipient, callData);
    }

    function _swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn, uint amountOutMin,
        ILBRouter.Path calldata path, uint256 balanceBefore,
        bool nativeIn, bool nativeOut, address logReceiver
    ) internal returns (uint) {
        address tokenIn = address(path.tokenPath[0]);
        address tokenOut = address(path.tokenPath[path.tokenPath.length-1]);

        IERC20(tokenIn).safeApprove(router, amountIn);

        ILBRouter(router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn, amountOutMin, path, address(this), block.timestamp+1
        );
        uint amountOut = IERC20(tokenOut).balanceOf(address(this)) - balanceBefore;

        if (nativeIn) tokenIn = address(0);
        if (nativeOut) tokenOut = address(0);

        return chargeAndLog(amountIn, tokenIn, amountOut, tokenOut, logReceiver);
    }

    function _swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        ILBRouter.Path calldata path,
        uint netFee, address logReceiver
    ) internal returns (uint) {
        require(msg.value > netFee, "OMOAggregator: INVALID_MSG_VALUE");
        require(address(path.tokenPath[0]) == WETH, "OMOAggregator: INVALID_FROM_TOKEN");

        IERC20 tokenOut = path.tokenPath[path.tokenPath.length-1];
        uint256 balanceBefore = IERC20(tokenOut).balanceOf(address(this));
        uint256 amountIn = msg.value - netFee;
        IWETH(WETH).deposit{value: amountIn}();

        return _swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn, amountOutMin, path, balanceBefore, true, false, logReceiver
        );
    }

    function chargeAndLog(
        uint256 amountIn,
        address tokenIn,
        uint256 amountOut,
        address tokenOut,
        address logReceiver
    ) internal returns (uint256) {
        uint feeAmount = amountOut * aggregatorFee / FEE_DENOMINATOR;

        if (tokenOut == WETH || tokenOut == address(0)) {
            IWETH(WETH).withdraw(feeAmount);
            _sendETH(feeCollector, feeAmount);
        } else {
            IERC20(tokenOut).safeTransfer(feeCollector, feeAmount);
        }

        emit LOG_AGG_SWAP(
            msg.sender,
            amountIn,
            tokenIn,
            amountOut,
            tokenOut,
            logReceiver,
            feeAmount
        );

        return amountOut - feeAmount;
    }

    function _sendETH(address to, uint256 amount) internal {
        (bool success,) = to.call{value:amount}(new bytes(0));
        require(success, 'OMOAggregator: ETH_TRANSFER_FAILED');
    }

    function setWETH(address _weth) external onlyOwner {
        WETH = _weth;
    }

    function setRouter(address _router) external onlyOwner {
        require(_router != address(0), "router address cannot be zero");
        router = _router;
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
