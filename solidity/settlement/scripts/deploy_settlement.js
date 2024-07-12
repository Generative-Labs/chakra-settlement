const hre = require("hardhat");
const { task } = require('hardhat/config')


async function main() {
    const settlementOwner = "0x4670555b56Af8491748EE76A22fcA80b4147dEc8"
    const settlementMansgers = ["0x4670555b56Af8491748EE76A22fcA80b4147dEc8", "0x71933Bff1C47CC475746AFA895feA150317404Aa"]

    const newSettlement = await ethers.getContractFactory("Settlement"); // Replace with your new contract name

    const chainId = 8545
    const requiredValidators = 2
    const chainName = "Chakra"
    const _signature_verifier = "0xA4Ba5728b519e30B5DF3D907fF843E63C25e9703";

    const settlmentInstance = await hre.upgrades.deployProxy(newSettlement, [
        chainName,
        chainId,
        settlementOwner,
        settlementMansgers,
        BigInt(requiredValidators),
        _signature_verifier,
    ]);

    await settlmentInstance.waitForDeployment();
    console.log("Settlement contract deployed to: ", await settlmentInstance.getAddress())
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});