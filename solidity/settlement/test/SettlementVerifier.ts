import { expect } from "chai";
import {
    loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";

import hre from "hardhat";
import { Contract, keccak256 } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { bigint } from "hardhat/internal/core/params/argumentTypes";

describe("Settlement", function () {
    const requiredValidators = 2;

    async function deploySettlementFixture() {
        const [
            verifierOwner,
        ] = await hre.ethers.getSigners();

        const SettlementSignatureVerifie = await hre.ethers.getContractFactory("SettlementSignatureVerifier");
        const verifyInstance = await hre.upgrades.deployProxy(SettlementSignatureVerifie, [
            await verifierOwner.getAddress(),
            requiredValidators
        ]);
        return { verifyInstance, verifierOwner }
    }



    it("SettlementVerifier should verified-1", async function () {
        const [validator1, validator2, validator3, manager] = await hre.ethers.getSigners();
        const { verifyInstance, verifierOwner } = await loadFixture(deploySettlementFixture)

        // Add the settlement contract as a manager
        await verifyInstance.connect(verifierOwner).add_manager(await manager.getAddress());

        const validators = [validator1, validator2, validator3]

        // Make a message hash
        const messageHash = hre.ethers.solidityPackedKeccak256(["address", "string"], [await verifyInstance.getAddress(), "test message"])

        for (let i = 0; i < validators.length; i++) {
            await verifyInstance.connect(manager).add_validator(await validators[i].getAddress());
        }


        let signatures = Buffer.from([]);
        for (let i = 0; i < validators.length - 1; i++) {
            const signature = await validators[i].signMessage(hre.ethers.getBytes(messageHash));
            const signatureBytes = Buffer.from(signature.slice(2), 'hex');
            signatures = Buffer.concat([signatures, signatureBytes]);
        }

        expect(await verifyInstance.verify(messageHash, signatures, 0)).to.equal(true);
    });

    it("SettlementVerifier should verified-2", async function () {
        const [validator1, validator2, validator3, manager] = await hre.ethers.getSigners();
        const { verifyInstance, verifierOwner } = await loadFixture(deploySettlementFixture)

        // Add the settlement contract as a manager
        await verifyInstance.connect(verifierOwner).add_manager(await manager.getAddress());

        const validators = [validator1, validator2, validator3]

        // Make a message hash
        const messageHash = hre.ethers.solidityPacked([
            "uint256",
            "string",
            "uint256",
            "uint256",
            "address",
            "bytes32"
        ], [
            BigInt("1449451617614920181705760328732352816800934224311"),
            "Arbitrum",
            '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
            '0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f',
            '0x8d75dde512738CCb31a82bE8E7dFfa96C40d7Aee',
            keccak256(Buffer.from('hello'))
        ])

        // console.log(hre.ethers.toBigInt(Buffer.from('0x70997970C51812dc3A010C7d01b50e0d17dc79C8'.slice(2), 'hex')),)
        // console.log(keccak256(Buffer.from('hello')))
        console.log(messageHash)

        for (let i = 0; i < validators.length; i++) {
            await verifyInstance.connect(manager).add_validator(await validators[i].getAddress());
        }


        let signatures = Buffer.from([]);
        for (let i = 0; i < validators.length - 1; i++) {
            const signature = await validators[i].signTypedData(hre.ethers.getBytes(messageHash));
            const signatureBytes = Buffer.from(signature.slice(2), 'hex');
            signatures = Buffer.concat([signatures, signatureBytes]);
        }

        expect(await verifyInstance.verify(messageHash, signatures, 0)).to.equal(true);
    });
});
