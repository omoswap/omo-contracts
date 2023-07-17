// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import './MockUniswapV2Pair.sol';
import "hardhat/console.sol";

contract MockUniswapV2Factory {
    mapping(address => mapping(address => address)) public getPair;

    function generateInitCode() external pure returns (bytes32) {
        bytes memory initCode = type(MockUniswapV2Pair).creationCode;
        return keccak256(initCode);
    }

    function createPair(address tokenA, address tokenB) public returns (address pair) {
        require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS'); // single check is sufficient
        
        bytes memory bytecode = type(MockUniswapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));

        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
            if iszero(extcodesize(pair)) {
                revert(0, 0)
            }
        }
        MockUniswapV2Pair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction

        return pair;
    }
}