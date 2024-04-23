// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

interface ISyncSwapPool {
    function token0() external view returns (address);
    function token1() external view returns (address);
}
