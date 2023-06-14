import { init, deployImpl, contractName } from "./common";
// import { ethers } from "hardhat";
import { chain } from "../constants";
import * as hre from "hardhat";

declare const global: any;

// E.g. [chain.Ethereum]: "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const deployed: {[key: string]: string} = {

}

async function main() {
    await init(deployed, 'Bridge', 'bridge', deploy);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

async function deploy() {
    const factory = await hre.ethers.getContractFactory(contractName);

    const tokenMessenger = ''
    const attester = ''
    const feeCollector = ''

    const instance = await factory.deploy(tokenMessenger, attester, feeCollector);

    deployImpl(instance);
}
