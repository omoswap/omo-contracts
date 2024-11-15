// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import "../../access/Ownable.sol";
import "../../interfaces/IBridge.sol";
import "../../assets/interfaces/IWETH.sol";
import "../interfaces/IPancakeSwapV3SwapRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract OMOLineaPancakeSwapV3Aggregator is Ownable {
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

    address public WETH = 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f;
    address public router = 0x1b81D678ffb9C0263b24A97847620C99d213eB14;
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

    function exactInput(
        IPancakeSwapV3SwapRouter.ExactInputParams memory params,
        bool unwrapETH
    ) external payable {
        (address tokenIn, address tokenOut) = decodeTokenInTokenOut(params);

        if (params.amountIn == 0) {
            require(msg.sender == IBridge(bridge).callProxy(), "invalid caller");
            params.amountIn = IERC20(tokenIn).allowance(msg.sender, address(this));
        }

        uint256 balanceBefore = IERC20(tokenOut).balanceOf(address(this));
        _pull(tokenIn, params.amountIn, 0);

        (uint amountOut, uint feeAmount, address receiver) = _swap(
            params, msg.value > 0, unwrapETH, params.recipient, balanceBefore
        );

        if (unwrapETH) {
            require(tokenOut == WETH, 'OMOAggregator: INVALID_TOKEN_OUT');

            IWETH(WETH).withdraw(amountOut);

            _sendETH(receiver, amountOut - feeAmount);
            _sendETH(feeCollector, feeAmount);
        } else {
            IERC20(tokenOut).safeTransfer(receiver, amountOut - feeAmount);
            IERC20(tokenOut).safeTransfer(feeCollector, feeAmount);
        }
    }

    function exactInputCrossChain(
        IPancakeSwapV3SwapRouter.ExactInputParams calldata params,
        uint netFee, uint32 destinationDomain, bytes32 recipient, bytes calldata callData // args for bridge
    ) external payable {
        (address tokenIn, address tokenOut) = decodeTokenInTokenOut(params);

        uint256 balanceBefore = IERC20(tokenOut).balanceOf(address(this));
        _pull(tokenIn, params.amountIn, netFee);

        (uint amountOut, uint feeAmount, ) = _swap(
            params, msg.value > netFee, false, msg.sender, balanceBefore
        );
        IERC20(tokenOut).safeTransfer(feeCollector, feeAmount);
        uint bridgeAmount = amountOut - feeAmount;

        IERC20(tokenOut).safeApprove(bridge, bridgeAmount);

        IBridge(bridge).bridgeOut{value: netFee}(
            tokenOut,
            bridgeAmount,
            destinationDomain,
            recipient,
            callData
        );
    }

    function _pull(address token, uint amount, uint netFee) internal {
        require(msg.value >= netFee, "OMOAggregator: invalid netFee");

        if (msg.value > netFee) {
            require(token == WETH, 'OMOAggregator: INVALID_TOKEN_IN');
            IWETH(WETH).deposit{value: msg.value - netFee}();
        } else {
            require(amount > 0, 'OMOAggregator: INSUFFICIENT_INPUT_AMOUNT');
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }
    }

    function _swap(
        IPancakeSwapV3SwapRouter.ExactInputParams memory params,
        bool nativeIn, bool nativeOut, address logReceiver, uint256 balanceBefore
    ) internal returns (uint, uint, address) {
        require(params.recipient != address(0), 'OMOAggregator: INVALID_RECIPIENT');
        address receiver = params.recipient;
        params.recipient = address(this);

        (address tokenIn, address tokenOut) = decodeTokenInTokenOut(params);

        IERC20(tokenIn).safeApprove(router, params.amountIn);

        if (params.deadline == 0) {
            params.deadline = block.timestamp+1;
        }

        IPancakeSwapV3SwapRouter(router).exactInput(params);
        uint amountOut = IERC20(tokenOut).balanceOf(address(this)) - balanceBefore;
        uint feeAmount = amountOut * aggregatorFee / FEE_DENOMINATOR;

        if (nativeIn) tokenIn = address(0);
        if (nativeOut) tokenOut = address(0);

        emit LOG_AGG_SWAP(
            msg.sender,
            params.amountIn,
            tokenIn,
            amountOut,
            tokenOut,
            logReceiver,
            feeAmount
        );

        return (amountOut, feeAmount, receiver);
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

    function decodeTokenInTokenOut(
        IPancakeSwapV3SwapRouter.ExactInputParams memory params
    ) internal pure returns (address, address) {
        require(params.path.length >= 43, 'toAddress_outOfBounds');
        bytes memory _bytes = params.path;

        address tokenIn;
        assembly {
            tokenIn := div(mload(add(add(_bytes, 0x20), 0)), 0x1000000000000000000000000)
        }

        address tokenOut;
        uint offset = _bytes.length-20;
        assembly {
            tokenOut := div(mload(add(add(_bytes, 0x20), offset)), 0x1000000000000000000000000)
        }

        return (tokenIn, tokenOut);
    }
}
