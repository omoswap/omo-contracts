// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.17;

import "./Utils.sol";
import "./access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CallProxy is Ownable2Step {
    using SafeERC20 for IERC20;

    address public bridge;

    event SetBridge(address bridge);

    modifier onlyBridge() {
        require(msg.sender == bridge, "CallProxy: no privilege");
        _;
    }

    function proxyCall(
        address token,
        uint256 amount,
        address receiver,
        bytes memory callData
    ) external onlyBridge returns (bool) {
        try this.decodeCallDataForExternalCall(callData) returns (address callee, bytes memory data) {
            IERC20(token).safeApprove(callee, 0);
            IERC20(token).safeApprove(callee, amount);

            require(callee != bridge, "invalid callee");
            require(callee != address(this), "invalid callee");

            callee.call(data);
        } catch {}

        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).safeTransfer(receiver, balance);
        }

        return true;
    }

    function setBridge(address newBridge) external onlyOwner {
        require(newBridge != address(0), "bridge address cannot be zero");
        bridge = newBridge;
        emit SetBridge(newBridge);
    }

    function rescueFund(address tokenAddress) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        token.safeTransfer(_msgSender(), token.balanceOf(address(this)));
    }

    function rescueNative(address receiver) external onlyOwner {
        (bool success, ) = receiver.call{ value: address(this).balance }("");
        require(success, "unable to send value, recipient may have reverted");
    }

    function decodeCallDataForExternalCall(bytes memory callData) external pure returns (
        address callee,
        bytes memory data
    ) {
        uint256 offset = 0;

        bytes memory calleeAddressBytes;
        (calleeAddressBytes, offset) = Utils.NextVarBytes(callData, offset);
        callee = Utils.bytesToAddress(calleeAddressBytes);

        (data, offset) = Utils.NextVarBytes(callData, offset);
    }
}
