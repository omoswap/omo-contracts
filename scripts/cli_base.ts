import { loadBaseUtils } from "./common";
import hre from "hardhat";
import { existsSync } from 'fs';

async function main() {
    const customLogic = 'readPrivKey.ts';
    if (existsSync(customLogic)) {
        let privateKey = require("../" + customLogic).privateKey;
        hre.network.config.accounts = [privateKey]
    }

    await loadBaseUtils();
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
