// SPDX-License-Identifier: AGPL-3.0

pragma solidity >=0.8.0;

interface ILynexRouter {
    struct Route {
        address from;
        address to;
        bool stable;
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external;
}
