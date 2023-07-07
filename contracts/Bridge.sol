// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.17;

import "./Utils.sol";
import "./roles/Attestable.sol";
import "./interfaces/IReceiver.sol";
import "./interfaces/ICallProxy.sol";
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
    address public callProxy;

    mapping(uint32 => bytes32) public bridgeHashMap;

    event SetTokenMessenger(address tokenMessenger);
    event SetUSDC(address USDC);
    event SetFeeCollector(address feeCollector);
    event SetCallProxy(address callProxy);
    event BindBridge(uint32 destinationDomain, bytes32 targetBridge);
    event BindBridgeBatch(uint32[] destinationDomains, bytes32[] targetBridges);
    event BridgeOut(address sender, uint32 destinationDomain, uint256 amount, uint64 nonce, bytes32 recipient, bytes callData, uint256 fee);
    event BridgeIn(address sender, address recipient, uint256 amount);

    struct TxArgs {
        bytes message;
        bytes mintAttestation;
        bytes32 recipient;
        bytes callData;
    }

    receive() external payable { }

    constructor(
        address _tokenMessenger,
        address _attester,
        address _feeCollector,
        address _usdc
        ) Attestable(_attester) {
        require(_tokenMessenger != address(0), "tokenMessenger address cannot be zero");
        require(_feeCollector != address(0), "feeCollector address cannot be zero");
        require(_usdc != address(0), "USDC address cannot be zero");

        tokenMessenger = _tokenMessenger;
        feeCollector = _feeCollector;
        USDC = _usdc;
    }

    function bridgeOut(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 recipient,
        bytes calldata callData
    ) external payable nonReentrant whenNotPaused {
        bytes32 targetBridge = bridgeHashMap[destinationDomain];
        require(targetBridge != bytes32(0), "target bridge not enabled");
        require(msg.sender != callProxy, "forbidden");
        require(recipient != bytes32(0), "recipient address cannot be zero");

        IERC20(USDC).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(USDC).safeApprove(tokenMessenger, amount);
        uint64 nonce = ITokenMessenger(tokenMessenger).depositForBurnWithCaller(
            amount, destinationDomain, targetBridge, USDC, targetBridge
        );

        sendNative(feeCollector, msg.value);
        emit BridgeOut(msg.sender, destinationDomain, amount, nonce, recipient, callData, msg.value);
    }

    function bridgeIn(
        bytes calldata args,
        bytes calldata attestation
    ) external nonReentrant whenNotPaused {
        require(args.length > 0, "invalid bridgeIn args");

        _verifyAttestationSignatures(args, attestation);

        TxArgs memory txArgs = deserializeTxArgs(args);

        uint256 balanceBefore = IERC20(USDC).balanceOf(address(this));
        bool success = _getMessageTransmitter().receiveMessage(txArgs.message, txArgs.mintAttestation);
        require(success, "receive message failed");
        uint256 amount = IERC20(USDC).balanceOf(address(this)) - balanceBefore;
        require(amount > 0, "amount cannot be zero");

        address recipient = bytes32ToAddress(txArgs.recipient);
        require(recipient != address(0), "recipient address cannot be zero");

        if (txArgs.callData.length != 0 && callProxy != address(0)) {
            IERC20(USDC).safeTransfer(callProxy, amount);
            require(ICallProxy(callProxy).proxyCall(USDC, amount, recipient, txArgs.callData), "proxy call failed");
        }

        uint256 balance = IERC20(USDC).balanceOf(address(this));
        if (balance > balanceBefore) {
            IERC20(USDC).safeTransfer(recipient, balance - balanceBefore);
        }

        emit BridgeIn(msg.sender, recipient, amount);
    }

    function getMessageTransmitter() external view returns (IReceiver) {
        return _getMessageTransmitter();
    }

    function _getMessageTransmitter() internal view returns (IReceiver) {
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

    function setCallProxy(address newCallProxy) onlyOwner external {
        callProxy = newCallProxy;
        emit SetCallProxy(newCallProxy);
    }

    function setFeeCollector(address newFeeCollector) external onlyOwner {
        require(newFeeCollector != address(0), "feeCollector address cannot be zero");

        feeCollector = newFeeCollector;
        emit SetFeeCollector(newFeeCollector);
    }

    function bindBridge(uint32 destinationDomain, bytes32 targetBridge) onlyOwner external returns (bool) {
        bridgeHashMap[destinationDomain] = targetBridge;
        emit BindBridge(destinationDomain, targetBridge);
        return true;
    }

    function bindBridgeBatch(uint32[] calldata destinationDomains, bytes32[] calldata targetBridgeHashes) onlyOwner external returns (bool) {
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
        (txArgs.mintAttestation, offset) = Utils.NextVarBytes(rawArgs, offset);

        bytes memory recipientBytes;
        (recipientBytes, offset) = Utils.NextVarBytes(rawArgs, offset);
        txArgs.recipient = addressToBytes32(Utils.bytesToAddress(recipientBytes));

        (txArgs.callData, offset) = Utils.NextVarBytes(rawArgs, offset);

        return txArgs;
    }

    // May revert if current chain does not implement the `BASEFEE` opcode
    function getBasefee() external view returns (uint256 basefee) {
        basefee = block.basefee;
    }

    function addressToBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    function bytes32ToAddress(bytes32 _buf) internal pure returns (address) {
        return address(uint160(uint256(_buf)));
    }
}
