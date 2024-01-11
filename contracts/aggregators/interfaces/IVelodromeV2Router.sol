// SPDX-License-Identifier: AGPL-3.0

pragma solidity >=0.8.0;

interface IVelodromeV2Router {
    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****

    /// @notice Swap one token for another supporting fee-on-transfer tokens
    /// @param amountIn     Amount of token in
    /// @param amountOutMin Minimum amount of desired token received
    /// @param routes       Array of trade routes used in the swap
    /// @param to           Recipient of the tokens received
    /// @param deadline     Deadline to receive tokens
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external;

    /// @notice Swap ETH for a token supporting fee-on-transfer tokens
    /// @param amountOutMin Minimum amount of desired token received
    /// @param routes       Array of trade routes used in the swap
    /// @param to           Recipient of the tokens received
    /// @param deadline     Deadline to receive tokens
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external payable;

    /// @notice Swap a token for WETH (returned as ETH) supporting fee-on-transfer tokens
    /// @param amountIn     Amount of token in
    /// @param amountOutMin Minimum amount of desired ETH
    /// @param routes       Array of trade routes used in the swap
    /// @param to           Recipient of the tokens received
    /// @param deadline     Deadline to receive tokens
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external;
}
