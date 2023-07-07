// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockPool {
    using SafeERC20 for IERC20;

    function swap(
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 amountIn,
        address to
    ) external returns (uint256) {
        tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);

        uint256 amountOut = amountIn * 2;
        tokenOut.safeTransfer(to, amountOut);

        return amountOut;
    }
}
