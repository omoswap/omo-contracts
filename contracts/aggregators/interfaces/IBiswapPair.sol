// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import "./IUniswapV2Pair.sol";

interface IBiswapPair is IUniswapV2Pair {
    function swapFee() external view returns (uint32);
    function devFee() external view returns (uint32);

    function setSwapFee(uint32) external;
    function setDevFee(uint32) external;
}
