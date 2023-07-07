import { FakeContract } from "@defi-wonderland/smock";
import { impersonateAccount, setBalance } from "@nomicfoundation/hardhat-network-helpers";
import { BaseContract, BigNumber, Wallet } from "ethers";
import { config, ethers } from "hardhat";

export const parseEther = ethers.utils.parseEther;
export const solidityPack = ethers.utils.solidityPack;

export const zeroAddress = ethers.constants.AddressZero;
export const anyString = ethers.utils.formatBytes32String("null");
export const emptyString = "0x";

export const sendEthParams = {
    value: parseEther("0.1"),
};

export async function getContractAccount(contract: BaseContract | FakeContract, balance = "1") {
    await impersonateAccount(contract.address);
    const account = ethers.provider.getSigner(contract.address);
    setBalance(contract.address, ethers.utils.parseEther(balance));
    return account;
}

export function getWalletByIndex(index: number): Wallet {
    const accounts: any = config.networks.hardhat.accounts;
    const wallet = ethers.Wallet.fromMnemonic(accounts.mnemonic, accounts.path + `/${index}`);
    return wallet.connect(ethers.provider);
}

function writeUint(v: number, length: number): Uint8Array {
    const hexString = BigNumber.from(v).toHexString().slice(2);
    const uint8Array = new Uint8Array(hexString.length / 2);
    for (let c = 0; c < hexString.length; c += 2) uint8Array[c / 2] = parseInt(hexString.slice(c, c + 2), 16);

    const uint256 = new Uint8Array(length / 8);
    uint256.set(uint8Array.reverse(), 0);

    return uint256;
}

function WriteVarUint(l: number) {
    if (l < 0xfd) {
        return writeUint(l, 8);
    } else if (l <= 0xffff) {
        return solidityPack(["uint8", "uint16"], [0xfd, writeUint(l, 16)]);
    } else if (l <= 0xffffffff) {
        return solidityPack(["uint8", "uint32"], [0xfe, writeUint(l, 32)]);
    } else {
        return solidityPack(["uint8", "uint64"], [0xff, writeUint(l, 64)]);
    }
}

export function writeVarBytes(data: string) {
    const l = ethers.utils.hexDataLength(data);
    return solidityPack(["bytes", "bytes"], [WriteVarUint(l), data]);
}

export function serializeCallData(toAddress: string, toChainId: number) {
    return solidityPack(["bytes", "uint64"], [writeVarBytes(toAddress), writeUint(toChainId, 64)]);
}

export function serializeTxArgs(args: any) {
    return ethers.utils.solidityPack(
        ["bytes", "bytes", "uint256", "bytes"],
        [
            writeVarBytes(args.toAssetHash),
            writeVarBytes(args.toAddress),
            writeUint(args.tokenId, 256),
            writeVarBytes(args.tokenURI),
        ]
    );
}

export function addressToBytes32(address: string) {
    return ethers.utils.hexZeroPad(address, 32);
}

export function signMessage(message: string, signers: Wallet) {
    const messageHash = ethers.utils.keccak256(message);
    const signature = new ethers.utils.SigningKey(signers.privateKey).signDigest(messageHash);
    const sig = signature.r + signature.s.replace("0x", "") + signature.v.toString(16);
    return sig;
}
