// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import "../../access/Ownable.sol";
import "../../interfaces/IBridge.sol";
import "../../assets/interfaces/IWETH.sol";
import "./interfaces/IAmbientDex.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
contract OMOScrollAmbientAggregator is Ownable {
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
    address public dex = 0xaaaaAAAACB71BF2C8CaE522EA5fa455571A74106;
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

    function userCmd(
        address tokenIn, address tokenOut,
        uint256 amountIn, address recipient,
        uint16 callpath, bytes calldata cmd
    ) external payable {
        require(recipient != address(0), "OMOAggregator: INVALID_RECIPIENT");

        if (amountIn == 0) {
            require(msg.sender == IBridge(bridge).callProxy(), "invalid caller");
            amountIn = IERC20(tokenIn).allowance(msg.sender, address(this));
        }

        (uint256 amountOut, uint256 feeAmount) = _pullAndSwap(
            tokenIn, tokenOut, amountIn,
            recipient, 0,
            callpath, cmd
        );

        if (tokenOut == address(0)) {
            _sendETH(recipient, amountOut - feeAmount);
            _sendETH(feeCollector, feeAmount);
        } else {
            if (tokenOut == WETH) {
                IWETH(WETH).deposit{value: amountOut}();
            }

            IERC20(tokenOut).safeTransfer(recipient, amountOut - feeAmount);
            IERC20(tokenOut).safeTransfer(feeCollector, feeAmount);
        }
    }

    function userCmdCrossChain(
        address tokenIn, address tokenOut, uint256 amountIn,
        uint16 callpath, bytes calldata cmd,
        uint256 netFee, uint32 destinationDomain, bytes32 recipient, bytes calldata callData
    ) external payable {
        (uint256 amountOut, uint256 feeAmount) = _pullAndSwap(
            tokenIn, tokenOut, amountIn,
            msg.sender, netFee,
            callpath, cmd
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
        require(amount > 0, 'OMOAggregator: INSUFFICIENT_INPUT_AMOUNT');

        if (msg.value > netFee) {
            require(token == address(0), 'OMOAggregator: INVALID_TOKEN_IN');
            require(msg.value - netFee >= amount, "OMOAggregator: INSUFFICIENT_INPUT_AMOUNT");
        } else {
            require(token != address(0), 'OMOAggregator: INVALID_TOKEN_IN');
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            if (token == WETH) {
                IWETH(WETH).withdraw(amount);
            }
        }
    }

    function _pullAndSwap(
        address tokenIn, address tokenOut, uint256 amountIn,
        address logReceiver, uint256 netFee,
        uint16 callpath, bytes calldata cmd
    ) internal returns (uint256, uint256) {
        uint256 amountOut;
        uint256 feeAmount;

        {
            uint256 balanceBefore = getTokenBalance(tokenOut);
            _pull(tokenIn, amountIn, netFee);

            if (tokenIn == address(0) || tokenIn == WETH) {
                IAmbientDex(dex).userCmd{value: amountIn}(callpath, cmd);
            } else {
                IERC20(tokenIn).safeApprove(dex, amountIn);
                IAmbientDex(dex).userCmd(callpath, cmd);
                IERC20(tokenIn).safeApprove(dex, 0);
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
        if (token == address(0) || token == WETH) {
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

    function setDex(address _dex) external onlyOwner {
        require(_dex != address(0), "dex address cannot be zero");
        dex = _dex;
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
