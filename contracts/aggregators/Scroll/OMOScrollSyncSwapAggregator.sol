// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import "../../access/Ownable.sol";
import "../../interfaces/IBridge.sol";
import "./interfaces/ISyncSwapPool.sol";
import "./interfaces/ISyncSwapRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract OMOScrollSyncSwapAggregator is Ownable {
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

    address public WETH = 0x5300000000000000000000000000000000000004;
    address public router = 0x80e38291e06339d10AAB483C65695D004dBD5C69;
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

    function swap(
        ISyncSwapRouter.SwapPath memory path,
        uint256 amountOutMin, uint256 deadline
    ) external payable {
        (address tokenIn, address tokenOut, address recipient) = handlePathParam(path);

        if (path.amountIn == 0) {
            require(msg.sender == IBridge(bridge).callProxy(), "invalid caller");
            path.amountIn = IERC20(tokenIn).allowance(msg.sender, address(this));
        }

        (uint256 amountOut, uint256 feeAmount) = _pullAndSwap(
            path, tokenIn, tokenOut, amountOutMin, deadline, recipient, 0
        );

         if (tokenOut == address(0)) {
            _sendETH(recipient, amountOut - feeAmount);
            _sendETH(feeCollector, feeAmount);
        } else {
            IERC20(tokenOut).safeTransfer(recipient, amountOut - feeAmount);
            IERC20(tokenOut).safeTransfer(feeCollector, feeAmount);
        }
    }

    function swapCrossChain(
        ISyncSwapRouter.SwapPath memory path,
        uint256 amountOutMin, uint256 deadline,
        uint256 netFee, uint32 destinationDomain, bytes32 recipient, bytes calldata callData
    ) external payable {
        (address tokenIn, address tokenOut,) = handlePathParam(path);

        (uint256 amountOut, uint256 feeAmount) = _pullAndSwap(
            path, tokenIn, tokenOut, amountOutMin, deadline, msg.sender, netFee
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

    function handlePathParam(
        ISyncSwapRouter.SwapPath memory path
    ) internal view returns (address, address, address) {
        require(path.steps.length > 0, "OMOAggregator: INVALID_SWAP_PATH");

        ISyncSwapRouter.SwapStep memory lastStep = path.steps[path.steps.length-1];
        (address lastTokenIn, address to, uint8 withdrawMode) = abi.decode(lastStep.data, (address, address, uint8));

        ISyncSwapPool pool = ISyncSwapPool(lastStep.pool);
        address tokenIn = path.tokenIn;
        address tokenOut = lastTokenIn == pool.token0() ? pool.token1() : pool.token0();

        lastStep.data = abi.encode(lastTokenIn, address(this), withdrawMode);

        return (tokenIn, tokenOut, to);
    }

    function _pull(address token, uint amount, uint netFee) internal {
        require(msg.value >= netFee, "OMOAggregator: invalid netFee");
        require(amount > 0, 'OMOAggregator: INSUFFICIENT_INPUT_AMOUNT');

        if (msg.value > netFee) {
            require(token == address(0), 'OMOAggregator: INVALID_TOKEN_IN');
            require(msg.value - netFee >= amount, "OMOAggregator: INSUFFICIENT_INPUT_AMOUNT");
        } else {
            require(token != address(0), 'OMOAggregator: INVALID_TOKEN_IN');
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }
    }

    function _pullAndSwap(
        ISyncSwapRouter.SwapPath memory path,
        address tokenIn, address tokenOut,
        uint256 amountOutMin, uint256 deadline,
        address logReceiver, uint256 netFee
    ) internal returns (uint256, uint256) {
        uint256 amountIn = path.amountIn;
        uint256 amountOut;
        uint256 feeAmount;

        {
            uint256 balanceBefore = getTokenBalance(tokenOut);
            _pull(tokenIn, amountIn, netFee);

            ISyncSwapRouter.SwapPath[] memory paths = new ISyncSwapRouter.SwapPath[](1);
            paths[0] = path;

            if (tokenIn == address(0)) {
                ISyncSwapRouter(router).swap{value: amountIn}(paths, amountOutMin, deadline);
            } else {
                IERC20(tokenIn).safeApprove(router, amountIn);
                ISyncSwapRouter(router).swap(paths, amountOutMin, deadline);
            }

            amountOut = getTokenBalance(tokenOut) - balanceBefore;
            feeAmount = amountOut * aggregatorFee / FEE_DENOMINATOR;
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

        return (amountOut, feeAmount);
    }

    function getTokenBalance(address token) internal view returns (uint256) {
        if (token == address(0)) {
            return address(this).balance;
        }

        return IERC20(token).balanceOf(address(this));
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
