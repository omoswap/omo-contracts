// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.17;

import "./Utils.sol";
import "./access/Ownable.sol";
import "./roles/Attestable.sol";
import "./interfaces/IReceiver.sol";
import "./interfaces/ITokenMessenger.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Bridge is Attestable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public USDC;
    address public feeCollector;
    address public tokenMessenger;
    mapping(uint32 => bytes) public bridgeHashMap;

    event SetTokenMessenger(address newTokenMessenger);
    event SetUSDC(address newUSDCAddress);
    event SetFeeCollector(address feeCollector);
    event BindBridge(uint32 destinationDomain, bytes targetBridge);
    event BindBridgeBatch(uint32[] destinationDomains, bytes[] targetBridges);
    event BridgeOut(address sender, uint32 destinationDomain, uint256 amount, uint64 nonce, bytes32 recipient, bytes callData, uint256 fee);
    event BridgeIn(address recipient, uint256 amount);

    struct TxArgs {
        bytes message;
        bytes attestation1;
        bytes32 mintRecipient;
        bytes callData;
    }

    receive() external payable { }

    constructor(
        address _tokenMessenger,
        address _attester,
        address _feeCollector
        ) Attestable(_attester) {
        require(_tokenMessenger != address(0), "tokenMessenger address cannot be zero");
        require(_feeCollector != address(0), "feeCollector address cannot be zero");

        tokenMessenger = _tokenMessenger;
    }

    function bridgeOut(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        bytes calldata callData
    ) external payable nonReentrant whenNotPaused {
        bytes memory targetBridge = bridgeHashMap[destinationDomain];
        require(targetBridge.length > 0, "target bridnge not enabled");

        uint64 nonce = ITokenMessenger(tokenMessenger).depositForBurnWithCaller(
            amount, destinationDomain, bytes32(targetBridge), USDC, bytes32(targetBridge)
        );

        sendNative(feeCollector, msg.value);
        emit BridgeOut(msg.sender, destinationDomain, amount, nonce, mintRecipient, callData, msg.value);
    }

    function bridgeIn(
        bytes calldata args,
        bytes calldata attestation
    ) external nonReentrant whenNotPaused {
        require(args.length > 0, "invalid bridgeIn args");

        _verifyAttestationSignatures(args, attestation);

        TxArgs memory txArgs = deserializeTxArgs(args);

        uint256 balanceBefore = IERC20(USDC).balanceOf(address(this));
        bool success = getReceiver().receiveMessage(txArgs.message, txArgs.attestation1);
        require(success, "receive message failed");
        uint256 amount = IERC20(USDC).balanceOf(address(this)) - balanceBefore;

        address receiver = bytes32ToAddress(txArgs.mintRecipient);

        executeExternalCall(txArgs.callData, receiver, amount);

        uint256 balance = IERC20(USDC).balanceOf(address(this));
        if (balance > balanceBefore) {
            IERC20(USDC).safeTransfer(receiver, balance - balanceBefore);
        }

        emit BridgeIn(receiver, amount);
    }

    function executeExternalCall(bytes memory callData, address receiver, uint256 amount) internal {
        if (callData.length == 0) {
            IERC20(USDC).safeTransfer(receiver, amount);
            return;
        }

        try this.decodeCallDataForExternalCall(callData) returns (address callee, bytes memory data) {
            IERC20(USDC).safeApprove(callee, 0);
            IERC20(USDC).safeApprove(callee, amount);

            require(callee != address(this), "invalid callee");

            callee.call(data);
        } catch {}
    }

    function getReceiver() internal view returns (IReceiver) {
        return IReceiver(ITokenMessenger(tokenMessenger).localMessageTransmitter());
    }

    function setTokenMessenger(address newTokenMessenger) onlyOwner external {
        require(newTokenMessenger != address(0), "tokenMessenger address cannot be zero");

        tokenMessenger = newTokenMessenger;
        emit SetTokenMessenger(newTokenMessenger);
    }

    function setUSDC(address newUSDCAddress) onlyOwner external {
        require(newUSDCAddress != address(0), "USDC address cannot be zero");
        USDC = newUSDCAddress;
        emit SetUSDC(newUSDCAddress);
    }

    function setFeeCollector(address newFeeCollector) external onlyOwner {
        require(newFeeCollector != address(0), "feeCollector address cannot be zero");

        feeCollector = newFeeCollector;
        emit SetFeeCollector(newFeeCollector);
    }

    function bindBridge(uint32 destinationDomain, bytes calldata targetBridge) onlyOwner external returns (bool) {
        bridgeHashMap[destinationDomain] = targetBridge;
        emit BindBridge(destinationDomain, targetBridge);
        return true;
    }

    function bindBridgeBatch(uint32[] calldata destinationDomains, bytes[] calldata targetBridgeHashes) onlyOwner external returns (bool) {
        require(destinationDomains.length == targetBridgeHashes.length, "Inconsistent parameter lengths");

        for (uint i = 0; i < destinationDomains.length; i++) {
            bridgeHashMap[destinationDomains[i]] = targetBridgeHashes[i];
        }

        emit BindBridgeBatch(destinationDomains, targetBridgeHashes);
        return true;
    }

    function externalCall(address callee, bytes calldata data) external onlyOwner {
        (bool success, ) = callee.call(data);
        require(success, "external call failed");
    }

    function rescueFund(address tokenAddress) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        token.safeTransfer(_msgSender(), token.balanceOf(address(this)));
    }

    function rescueNative(address receiver) external onlyOwner {
        sendNative(receiver, address(this).balance);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function sendNative(address receiver, uint256 amount) internal {
        (bool success, ) = receiver.call{ value: amount }("");
        require(success, "unable to send value, recipient may have reverted");
    }

    function deserializeTxArgs(bytes calldata rawArgs) internal pure returns (TxArgs memory) {
        TxArgs memory txArgs;
        uint256 offset = 0;
        (txArgs.message, offset) = Utils.NextVarBytes(rawArgs, offset);
        (txArgs.attestation1, offset) = Utils.NextVarBytes(rawArgs, offset);

        bytes memory mintRecipient;
        (mintRecipient, offset) = Utils.NextVarBytes(rawArgs, offset);
        txArgs.mintRecipient = addressToBytes32(Utils.bytesToAddress(mintRecipient));

        (txArgs.callData, offset) = Utils.NextVarBytes(rawArgs, offset);

        return txArgs;
    }

    function decodeCallDataForExternalCall(bytes memory callData) external pure returns (
        address callee,
        bytes memory data
    ) {
        uint256 offset = 0;

        bytes memory calleeAddressBytes;
        (calleeAddressBytes, offset) = Utils.NextVarBytes(callData, offset);
        callee = Utils.bytesToAddress(calleeAddressBytes);

        (data, offset) = Utils.NextVarBytes(callData, offset);
    }

    function addressToBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    function bytes32ToAddress(bytes32 _buf) internal pure returns (address) {
        return address(uint160(uint256(_buf)));
    }
}
