// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import "../interfaces/IMessageTransmitter.sol";
import "../roles/Attestable.sol";
import "../libraries/Utils.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockMessageTransmitter is IMessageTransmitter, Attestable {
    using SafeERC20 for IERC20;

    address public USDC;

    constructor(address _attester, address _usdc) Attestable(_attester) {
        USDC = _usdc;
    }

    function receiveMessage(
        bytes calldata message,
        bytes calldata attestation
    ) external override returns (bool success) {
        _verifyAttestationSignatures(message, attestation);

        address recipient = Utils.bytesToAddress(message);
        uint256 amount = 10;
        IERC20(USDC).safeTransfer(recipient, amount);

        return true;
    }

    function addressToBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    function localDomain() external view override returns (uint32) {}
}
