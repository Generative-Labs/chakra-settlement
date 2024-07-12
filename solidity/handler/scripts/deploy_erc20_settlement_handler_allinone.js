// scripts/deploy-my-collectible.js
const hre = require("hardhat");
const { task } = require('hardhat/config')


async function main() {
    // 1. Deploy Token Contract
    const tokenOwner = "<You token owner address>"
    const tokenOperator = "<You token operator address>"
    const decimals = 8
    const name = "MyToken"
    const symbol = "MKT"
    const ChakraBTC = await hre.ethers.getContractFactory("MyToken")
    const tokenInstance = await hre.upgrades.deployProxy(ChakraBTC, [tokenOwner, tokenOperator, name, symbol, decimals]);
    await tokenInstance.waitForDeployment();
    const tokenAddress = await tokenInstance.getAddress();
    console.log("ChakraBTC contract deployed to: ", tokenAddress)


    // 2. Deploy Codec Contract
    const codecOwner = "<You codec owner address>"
    const ERC20CodecV1 = await hre.ethers.getContractFactory("ERC20CodecV1");
    const codecInstance = await hre.upgrades.deployProxy(ERC20CodecV1, [codecOwner]);
    await codecInstance.waitForDeployment();
    console.log("Codec contract deployed to: ", await codecInstance.getAddress())


    // 3. Deploy Verify Contract
    const verifyOwner = "<You verify owner address>"
    const VerifyV1 = await hre.ethers.getContractFactory("SettlementSignatureVerifier");
    const verifyInstance = await hre.upgrades.deployProxy(VerifyV1, [verifyOwner]);
    await verifyInstance.waitForDeployment();
    console.log("Verify contract deployed to: ", await verifyInstance.getAddress())

    // 4. Deploy SettlementHandler Contract
    const no_burn = true;
    const chain = "<You chain name>"
    const settlementContractAddress = "<You settlement contract address>"
    const settlementHandlerOwner = "<You settlement handler owner address>"
    const ERC20SettlementHandler = await hre.ethers.getContractFactory("ChakraSettlementHandler");
    const settlementHandlerInstance = await hre.upgrades.deployProxy(ERC20SettlementHandler, [
        settlementHandlerOwner,
        no_burn,
        chain,
        await tokenInstance.getAddress(),
        await codecInstance.getAddress(),
        await verifyInstance.getAddress(),
        settlementContractAddress
    ]);

    await settlementHandlerInstance.waitForDeployment();
    console.log("SettlementHandler contract deployed to: ", await settlementHandlerInstance.getAddress())
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});