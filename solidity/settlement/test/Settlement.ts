import { expect } from "chai";
import {
    loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";

import hre from "hardhat";
import { Contract } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";

describe("ChakraSettlement", function () {
    const chainId = 1;
    const chainName = "test"
    const requiredValidators = 2;
    const decimals = 8;
    const name = "MyToken"
    const symbol = "MKT"
    const noBurn = false;

    async function deploySettlementFixture() {
        const [
            tokenOwner,
            tokenOperator,
            manager,
            settlementOwner,
            settlementHnadlerOwner,
        ] = await hre.ethers.getSigners();
        const MyToken = await hre.ethers.getContractFactory("MyToken");
        const tokenInstance = await hre.upgrades.deployProxy(MyToken, [
            await tokenOwner.getAddress(),
            await tokenOperator.getAddress(),
            name,
            symbol,
            decimals
        ]);

        const SettlementSignatureVerifier = await hre.ethers.getContractFactory("SettlementSignatureVerifier");
        const verifierInstance = await hre.upgrades.deployProxy(SettlementSignatureVerifier, [
            await settlementOwner.getAddress(),
            requiredValidators
        ]);


        const ChakraSettlement = await hre.ethers.getContractFactory("ChakraSettlement");
        const settlmentInstance = await hre.upgrades.deployProxy(ChakraSettlement, [
            chainName,
            BigInt(chainId),
            await settlementOwner.getAddress(),
            [await manager.getAddress()],
            BigInt(requiredValidators),
            await verifierInstance.getAddress(),
        ]);

        const ERC20CodecV1 = await hre.ethers.getContractFactory('ERC20CodecV1');
        const codecInstance = await hre.upgrades.deployProxy(ERC20CodecV1, [
            await settlementHnadlerOwner.getAddress(),
        ])
        const ERC20SettlementHandler = await hre.ethers.getContractFactory('ERC20SettlementHandler');
        const settlementHandlerInstance = await hre.upgrades.deployProxy(ERC20SettlementHandler, [
            await settlementHnadlerOwner.getAddress(), // owner
            noBurn, // no_burn
            chainName, //chain
            await tokenInstance.getAddress(), // token
            await codecInstance.getAddress(), // codec
            await verifierInstance.getAddress(), // verifier
            await settlmentInstance.getAddress(), // settlement

        ])

        const MessageLibTest = await hre.ethers.getContractFactory('MessageLibTest')
        const messageLibTestInstance = await MessageLibTest.deploy()


        return { tokenInstance, settlmentInstance, settlementHandlerInstance, verifierInstance, messageLibTestInstance, tokenOwner, tokenOperator, manager, settlementOwner }
    }

    // async function sendDepositRequest(btcTxId: BigInt, amount: number, settlmentInstance: Contract, settlementDepositer: HardhatEthersSigner) {
    //     const [sender, receiver] = await hre.ethers.getSigners();
    //     const toChainId = 2;
    //     const fromChainName = ""
    //     const toChainName = ""

    //     await settlmentInstance.connect(settlementDepositer).deposit_request(
    //         btcTxId,
    //         BigInt(chainId),
    //         BigInt(toChainId),
    //         fromChainName,
    //         toChainName,
    //         await sender.getAddress(),
    //         await receiver.getAddress(),
    //         amount
    //     );

    //     return { sender, receiver }

    // }

    it("Should managed validators correctly", async function () {
        const [validator1, validator2, validator3] = await hre.ethers.getSigners();
        const { settlmentInstance, verifierInstance, manager, settlementOwner } = await loadFixture(deploySettlementFixture)

        // Add the settlement contract as a manager
        await verifierInstance.connect(settlementOwner).add_manager(await settlmentInstance.getAddress());


        const validators = [validator1, validator2, validator3]

        // Check that the validators are correctly added
        for (let i = 0; i < validators.length; i++) {
            await settlmentInstance.connect(manager).add_validator(await validators[i].getAddress());
            expect(await settlmentInstance.is_validator(await validators[i].getAddress())).to.equal(true);
            expect(await verifierInstance.is_validator(await validators[i].getAddress())).to.equal(true);
        }

        // Check that the validators added but not allow added again
        for (let i = 0; i < validators.length; i++) {
            await expect(settlmentInstance.connect(manager).add_validator(await validators[i].getAddress()))
                .to.be.revertedWith("Validator already exists")
        }


        // Check that the validators are correctly removed
        for (let i = 0; i < validators.length; i++) {
            await settlmentInstance.connect(manager).remove_validator(await validators[i].getAddress());
            expect(await settlmentInstance.is_validator(await validators[i].getAddress())).to.equal(false);
            expect(await verifierInstance.is_validator(await validators[i].getAddress())).to.equal(false);
        }

        // Check that the validators removed but not allow removed again
        for (let i = 0; i < validators.length; i++) {
            await expect(settlmentInstance.connect(manager).remove_validator(await validators[i].getAddress()))
                .to.be.revertedWith("Validator does not exists")
        }
    });

    it("Should send message", async function () {

    })

    // it("Chakra settlement should deposit request successful", async function () {
    //     const [sender, receiver] = await hre.ethers.getSigners();
    //     const { settlmentInstance, settlementDepositer } = await loadFixture(deploySettlementFixture)

    //     const btcTxId = hre.ethers.toBigInt(Buffer.from("7b09bfd0070ec50ba95640fcf078907a8ea1fd109e4979abbd073a34b2c2787e", 'hex'))
    //     const toChainId = 2;
    //     const fromChainName = ""
    //     const toChainName = ""
    //     const amount = 500

    //     const senderAddress = await sender.getAddress();
    //     const receiverAddress = await receiver.getAddress();
    //     const depositRequestTx = await settlmentInstance.connect(settlementDepositer).deposit_request(
    //         btcTxId,
    //         BigInt(chainId),
    //         BigInt(toChainId),
    //         fromChainName,
    //         toChainName,
    //         senderAddress,
    //         receiverAddress,
    //         amount
    //     );

    //     // Check that event is emitted
    //     await expect(depositRequestTx)
    //         .to.emit(settlmentInstance, 'DepositRequest')
    //         .withArgs(btcTxId,
    //             senderAddress,
    //             receiverAddress,
    //             amount,
    //             chainId,
    //             toChainId,
    //             fromChainName,
    //             toChainName
    //         );

    //     // Check that status should equals pending
    //     expect(await settlmentInstance.get_transaction_status(btcTxId)).to.be.equal(1);

    //     // bad request should revert
    //     await expect(
    //         settlmentInstance.connect(settlementDepositer).deposit_request(
    //             btcTxId,
    //             BigInt(chainId),
    //             BigInt(toChainId),
    //             fromChainName,
    //             toChainName,
    //             await sender.getAddress(),
    //             await receiver.getAddress(),
    //             amount
    //         )
    //     ).to.be.revertedWith("Deposit request already exists");
    // });

    // it("Chakra settlement deposit request should revert due bad role", async function () {
    //     const [sender, receiver] = await hre.ethers.getSigners();
    //     const { settlmentInstance, settlementDepositer } = await loadFixture(deploySettlementFixture)

    //     const btcTxId = hre.ethers.toBigInt(Buffer.from("7b09bfd0070ec50ba95640fcf078907a8ea1fd109e4979abbd073a34b2c2787e", 'hex'))
    //     const toChainId = 2;
    //     const fromChainName = ""
    //     const toChainName = ""
    //     const amount = 500

    //     const senderAddress = await sender.getAddress();
    //     const receiverAddress = await receiver.getAddress();

    //     await expect(
    //         settlmentInstance.connect(sender).deposit_request(
    //             btcTxId,
    //             BigInt(chainId),
    //             BigInt(toChainId),
    //             fromChainName,
    //             toChainName,
    //             senderAddress,
    //             receiverAddress,
    //             amount
    //         )
    //     ).to.be.revertedWithCustomError(settlmentInstance, "AccessControlUnauthorizedAccount");
    // });

});
