import { ethers } from "hardhat";

export async function generateInitCode() {
  const mockUniswapV2FactoryFactory = await ethers.getContractFactory("MockUniswapV2Factory");
  const mockUniswapV2Factory = await mockUniswapV2FactoryFactory.deploy();
  console.log(await mockUniswapV2Factory.generateInitCode());
}

describe("", function () {
  it("initCode", async function () {
    await generateInitCode();
  });
});
