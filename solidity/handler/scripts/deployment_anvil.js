const hre = require("hardhat");
const { task } = require('hardhat/config')


async function main() {
    const chainName = "Local_test"

    const owner = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

    const ERC20CodecV1 = await hre.ethers.getContractFactory("ERC20CodecV1");
    const codecInstance = await hre.upgrades.deployProxy(ERC20CodecV1, [
        owner,
    ]);

    await codecInstance.waitForDeployment();
    console.log("ERC20CodecV1 contract deployed to: ", await codecInstance.getAddress())

    // Setup token
    const tokenOperator = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
    const tokenName = "MyToken"
    const tokenSymbol = "MKT"
    const tokenDecimal = 8

    const MyToken = await hre.ethers.getContractFactory("ChakraToken");
    const tokenInstance = await hre.upgrades.deployProxy(MyToken, [
        owner,
        tokenOperator,
        tokenName,
        tokenSymbol,
        tokenDecimal
    ]);


    await tokenInstance.waitForDeployment();
    console.log("MyToken contract deployed to: ", await tokenInstance.getAddress())

    // Setup handler
    const verifierAddress = "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0"
    const settlementAddress = "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9"
    const settlementHandlerMode = 0; // MintBurn

    const ChakraSettlementHandler = await hre.ethers.getContractFactory("ChakraSettlementHandler");
    const handlerInstance = await hre.upgrades.deployProxy(ChakraSettlementHandler, [
        owner,
        settlementHandlerMode,
        chainName,
        await tokenInstance.getAddress(),
        await codecInstance.getAddress(),
        verifierAddress,
        settlementAddress,
    ]);

    await handlerInstance.waitForDeployment();
    console.log("ChakraSettlementHandler contract deployed to: ", await handlerInstance.getAddress())
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});