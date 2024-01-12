// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import "../../access/Ownable.sol";
import "../interfaces/ICurve.sol";
import "../../interfaces/IBridge.sol";
import "../../assets/interfaces/IWETH.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract OMOEthereumCurveAggregator is Ownable {
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

    address public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public bridge = 0xa39628ee6Ca80eb2D93f21Def75A7B4D03b82e1E;
    address public feeCollector;

    uint256 public aggregatorFee = 4 * 10**6;
    uint256 public constant FEE_DENOMINATOR = 10 ** 10;
    uint256 private constant MAX_AGGREGATOR_FEE = 5 * 10**8;

    constructor (address _feeCollector) {
        require(_feeCollector != address(0), "feeCollector address cannot be zero");
        feeCollector = _feeCollector;
    }

    receive() external payable { }

    function exchangeTokensForTokens(
        uint256 amountIn,
        address pool,
        uint256 minDy,
        address[] calldata path,
        address receiver,
        bool unwrapETH
    ) external virtual {
        if (amountIn == 0) {
            require(_msgSender() == IBridge(bridge).callProxy(), "invalid caller");
            amountIn = IERC20(path[0]).allowance(_msgSender(), address(this));
        }

        IERC20(path[0]).safeTransferFrom(_msgSender(), address(this), amountIn);

        uint256 amountOutCharged = _exchangeTokensForTokens(
            amountIn, pool, minDy, path, false, unwrapETH, receiver
        );

        if (unwrapETH) {
            require(path[1] == WETH, 'OMOAggregator: INVALID_PATH');
            IWETH(WETH).withdraw(amountOutCharged);
            _sendETH(receiver, amountOutCharged);
        } else {
            IERC20(path[1]).safeTransfer(receiver, amountOutCharged);
        }
    }

    function exchangeTokensForTokensCrossChain(
        uint256 amountIn, address pool, uint256 minDy, address[] calldata path,
        uint32 destinationDomain, bytes32 recipient, bytes calldata callData
    ) external virtual payable {
        IERC20(path[0]).safeTransferFrom(_msgSender(), address(this), amountIn);

        uint256 bridgeAmount = _exchangeTokensForTokens(
            amountIn, pool, minDy, path, false, false, _msgSender()
        );

        IERC20(path[1]).safeApprove(bridge, bridgeAmount);
        IBridge(bridge).bridgeOut{value: msg.value}(path[1], bridgeAmount, destinationDomain, recipient, callData);
    }

    function exchangeETHForTokens(
        address pool,
        address[] calldata path,
        uint256 minDy,
        address receiver
    ) external payable {
        uint256 amountIn = msg.value;
        IWETH(WETH).deposit{value: amountIn}();

        require(path[0] == WETH, 'OMOAggregator: INVALID_PATH');

        uint256 amountOutCharged = _exchangeTokensForTokens(
            amountIn, pool, minDy, path, true, false, receiver
        );

        IERC20(path[1]).safeTransfer(receiver, amountOutCharged);
    }

    function exchangeETHForTokensCrossChain(
        address pool, uint256 minDy, address[] calldata path,
        uint256 netFee, uint32 destinationDomain, bytes32 recipient, bytes calldata callData
    ) external payable {
        uint256 amountIn = msg.value - netFee;
        IWETH(WETH).deposit{value: amountIn}();

        require(path[0] == WETH, 'OMOAggregator: INVALID_PATH');
        uint256 bridgeAmount = _exchangeTokensForTokens(
            amountIn, pool, minDy, path, true, false, msg.sender
        );

        IERC20(path[1]).safeApprove(bridge, bridgeAmount);
        IBridge(bridge).bridgeOut{value: netFee}(path[1], bridgeAmount, destinationDomain, recipient, callData);
    }

    function _exchangeTokensForTokens(
        uint256 amountIn,
        address pool,
        uint256 minDy,
        address[] calldata path,
        bool nativeIn,
        bool nativeOut,
        address logReceiver
    ) internal returns (uint256) {
        uint256 amountOut = _curveSwap(pool, amountIn, path, minDy);
        uint256 feeAmount = amountOut * aggregatorFee / FEE_DENOMINATOR;

        if (path[1] != WETH) {
            IERC20(path[1]).safeTransfer(feeCollector, feeAmount);
        } else {
            IWETH(WETH).withdraw(feeAmount);
            _sendETH(feeCollector, feeAmount);
        }

        address tokenIn = path[0];
        if (nativeIn) tokenIn = address(0);

        address tokenOut = path[1];
        if (nativeOut) tokenOut = address(0);

        emit LOG_AGG_SWAP(
            msg.sender,
            amountIn,
            tokenIn,
            amountOut,
            tokenOut,
            logReceiver,
            feeAmount
        );

        return (amountOut - feeAmount);
    }

    function _curveSwap(
        address pool,
        uint256 amountIn,
        address[] calldata path,
        uint256 minDy
    ) internal returns (uint256) {
        require(amountIn != 0, "OMOAggregator: amountIn cannot be zero");
        require(path.length == 2, "OMOAggregator: INVALID_PATH");

        IERC20(path[0]).safeApprove(pool, amountIn);
        (int128 i, int128 j) = _getPoolTokenIndex(pool, path[0], path[1]);

        address toToken = path[1];
        uint256 balanceBefore = IERC20(toToken).balanceOf(address(this));
        (bool success, ) = pool.call(abi.encodeWithSelector(ICurve.exchange.selector, i, j, amountIn, minDy));
        require(success, "OMOAggregator: curve exchange failed");

        return IERC20(toToken).balanceOf(address(this)) - balanceBefore;
    }

    function _getPoolTokenIndex(
        address pool,
        address fromToken,
        address toToken
    ) internal returns (int128, int128) {
        int128 i;
        int128 j;
        uint8 found = 0x00;

        for (int128 idx = 0; idx < 8; idx++) {
            address coin = ICurve(pool).coins(uint256(uint128(idx)));
            if (coin == fromToken) {
                i = int128(idx);
                found |= uint8(0x1);
            } else if (coin == toToken) {
                j = int128(idx);
                found |= uint8(0x2);
            }

            if (found == 0x03) {
                return (i, j);
            }
        }

        revert("token not pooled");
    }

    function setWETH(address _weth) external onlyOwner {
        WETH = _weth;
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

    function _sendETH(address to, uint256 amount) internal {
        (bool success,) = to.call{value:amount}(new bytes(0));
        require(success, 'OMOAggregator: ETH_TRANSFER_FAILED');
    }
}
