// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

interface IAmbientDex {
    function userCmd(uint16 callpath, bytes calldata cmd) external payable returns (bytes memory);
}
