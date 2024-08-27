const hre = require("hardhat");
const { task } = require('hardhat/config')


async function main() {


    const chainId = 8545
    const requiredValidators = 1
    const chainName = "Local_test"

    const owner = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
    const settlementMansgers = ["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"]
    const SettlementSignatureVerifie = await hre.ethers.getContractFactory("SettlementSignatureVerifier");
    const verifyInstance = await hre.upgrades.deployProxy(SettlementSignatureVerifie, [
        owner,
        requiredValidators
    ]);
    await verifyInstance.waitForDeployment();
    console.log("SettlementSignatureVerifier contract deployed to: ", await verifyInstance.getAddress())

    const Settlement = await hre.ethers.getContractFactory("ChakraSettlement");
    const settlmentInstance = await hre.upgrades.deployProxy(Settlement, [
        chainName,
        BigInt(chainId),
        owner,
        settlementMansgers,
        requiredValidators,
        await verifyInstance.getAddress(),
    ]);

    await settlmentInstance.waitForDeployment();
    console.log("Settlement contract deployed to: ", await settlmentInstance.getAddress())


    const MessageLibTest = await hre.ethers.getContractFactory("MessageLibTest");
    const messageLibTestInstance = await MessageLibTest.deploy();

    await messageLibTestInstance.waitForDeployment();
    console.log("MessageLibTest contract deployed to: ", await messageLibTestInstance.getAddress())



    // Add the settlement contract as a manager
    await verifyInstance.add_manager(await settlmentInstance.getAddress());
    console.log("Settlement contract added as manager to SettlementSignatureVerifier contract: ", await settlmentInstance.getAddress())

    await verifyInstance.add_manager(owner);
    console.log("Owner contract added as manager to SettlementSignatureVerifier contract: ", owner)
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});