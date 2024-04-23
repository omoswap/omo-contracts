// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

interface ISyncSwapRouter {
    struct SwapStep {
        address pool;
        bytes data;
        address callback;
        bytes callbackData;
    }

    struct SwapPath {
        SwapStep[] steps;
        address tokenIn;
        uint amountIn;
    }

    struct SplitPermitParams {
        address token;
        uint approveAmount;
        uint deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct ArrayPermitParams {
        uint approveAmount;
        uint deadline;
        bytes signature;
    }

    function swap(
        SwapPath[] memory paths,
        uint amountOutMin,
        uint deadline
    ) external payable;
}
