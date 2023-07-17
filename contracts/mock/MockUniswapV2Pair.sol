// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockUniswapV2Pair {
    using SafeERC20 for IERC20;

    address public token0;
    address public token1;

    function initialize(address _token0, address _token1) external {
        token0 = _token0;
        token1 = _token1;
    }

    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external {
        require(data.length >= 0, "Invalid data length");
       
        if (amount0Out > 0) {
            IERC20(token0).safeTransfer(to, amount0Out * 2);
        } 
        if (amount1Out > 0) {
            IERC20(token1).safeTransfer(to, amount1Out * 2);
        }
    }

    function getReserves() public pure returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        return (9999, 9999, 0);
    }
}
