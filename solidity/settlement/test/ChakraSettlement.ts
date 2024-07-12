import { expect } from "chai";
import {
    loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";

import hre from "hardhat";
import { Contract } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";

describe("ExtendERC20", function () {
    const chainId = 1;
    const requiredValidators = 2;
    const ckrBTCDecimals = 8;

    async function deploySettlementFixture() {
        const [deployer, settlementOwner, settlementManager, settlementDepositer, extendERC20Owner, tokenOwner, tokenMinter, tokenBuner] = await hre.ethers.getSigners();
        const ChakraBTC = await hre.ethers.getContractFactory("ChakraBTC");
        const chakraBTCInstance = await hre.upgrades.deployProxy(ChakraBTC, [await tokenOwner.getAddress(), ckrBTCDecimals]);

        const ExtendERC20 = await hre.ethers.getContractFactory("ExtendERC20");
        const extendERC20Instance = await hre.upgrades.deployProxy(ExtendERC20, [await extendERC20Owner.getAddress(), await tokenMinter.getAddress(), await tokenOwner.getAddress(), await chakraBTCInstance.getAddress()]);


        const Settlement = await hre.ethers.getContractFactory("ChakraSettlement");
        const settlmentInstance = await hre.upgrades.deployProxy(Settlement, [await settlementOwner.getAddress(), [await settlementManager.getAddress()], [await settlementDepositer.getAddress()], BigInt(chainId), await extendERC20Instance.getAddress(), BigInt(requiredValidators)]);
        return { chakraBTCInstance, extendERC20Instance, settlmentInstance, deployer, extendERC20Owner, settlementOwner, settlementDepositer, settlementManager, tokenOwner, tokenMinter, tokenBuner }
    }

    async function sendDepositRequest(btcTxId: BigInt, amount: number, settlmentInstance: Contract, settlementDepositer: HardhatEthersSigner) {
        const [sender, receiver] = await hre.ethers.getSigners();
        const toChainId = 2;
        const fromChainName = ""
        const toChainName = ""

        await settlmentInstance.connect(settlementDepositer).deposit_request(
            btcTxId,
            BigInt(chainId),
            BigInt(toChainId),
            fromChainName,
            toChainName,
            await sender.getAddress(),
            await receiver.getAddress(),
            amount
        );

        return { sender, receiver }

    }

    it("Chakra settlement should managed validators correctly", async function () {
        const [validator1, validator2, validator3] = await hre.ethers.getSigners();
        const { settlmentInstance, settlementManager } = await loadFixture(deploySettlementFixture)


        const validators = [validator1, validator2, validator3]

        // Check that the validators are correctly added
        for (let i = 0; i < validators.length; i++) {
            await settlmentInstance.connect(settlementManager).add_validator(await validators[i].getAddress());
            expect(await settlmentInstance.is_validator(await validators[i].getAddress())).to.equal(true);
        }

        // Check that the validators added but not allow added again
        for (let i = 0; i < validators.length; i++) {
            await expect(settlmentInstance.connect(settlementManager).add_validator(await validators[i].getAddress()))
                .to.be.revertedWith("Validator already exists")
        }


        // Check that the validators are correctly removed
        for (let i = 0; i < validators.length; i++) {
            await settlmentInstance.connect(settlementManager).remove_validator(await validators[i].getAddress());
            expect(await settlmentInstance.is_validator(await validators[i].getAddress())).to.equal(false);
        }

        // Check that the validators removed but not allow removed again
        for (let i = 0; i < validators.length; i++) {
            await expect(settlmentInstance.connect(settlementManager).remove_validator(await validators[i].getAddress()))
                .to.be.revertedWith("Validator does not exists")
        }
    });

    it("Chakra settlement should deposit request successful", async function () {
        const [sender, receiver] = await hre.ethers.getSigners();
        const { settlmentInstance, settlementDepositer } = await loadFixture(deploySettlementFixture)

        const btcTxId = hre.ethers.toBigInt(Buffer.from("7b09bfd0070ec50ba95640fcf078907a8ea1fd109e4979abbd073a34b2c2787e", 'hex'))
        const toChainId = 2;
        const fromChainName = ""
        const toChainName = ""
        const amount = 500

        const senderAddress = await sender.getAddress();
        const receiverAddress = await receiver.getAddress();
        const depositRequestTx = await settlmentInstance.connect(settlementDepositer).deposit_request(
            btcTxId,
            BigInt(chainId),
            BigInt(toChainId),
            fromChainName,
            toChainName,
            senderAddress,
            receiverAddress,
            amount
        );

        // Check that event is emitted
        await expect(depositRequestTx)
            .to.emit(settlmentInstance, 'DepositRequest')
            .withArgs(btcTxId,
                senderAddress,
                receiverAddress,
                amount,
                chainId,
                toChainId,
                fromChainName,
                toChainName
            );

        // Check that status should equals pending
        expect(await settlmentInstance.get_transaction_status(btcTxId)).to.be.equal(1);

        // bad request should revert
        await expect(
            settlmentInstance.connect(settlementDepositer).deposit_request(
                btcTxId,
                BigInt(chainId),
                BigInt(toChainId),
                fromChainName,
                toChainName,
                await sender.getAddress(),
                await receiver.getAddress(),
                amount
            )
        ).to.be.revertedWith("Deposit request already exists");
    });

    it("Chakra settlement deposit request should revert due bad role", async function () {
        const [sender, receiver] = await hre.ethers.getSigners();
        const { settlmentInstance, settlementDepositer } = await loadFixture(deploySettlementFixture)

        const btcTxId = hre.ethers.toBigInt(Buffer.from("7b09bfd0070ec50ba95640fcf078907a8ea1fd109e4979abbd073a34b2c2787e", 'hex'))
        const toChainId = 2;
        const fromChainName = ""
        const toChainName = ""
        const amount = 500

        const senderAddress = await sender.getAddress();
        const receiverAddress = await receiver.getAddress();

        await expect(
            settlmentInstance.connect(sender).deposit_request(
                btcTxId,
                BigInt(chainId),
                BigInt(toChainId),
                fromChainName,
                toChainName,
                senderAddress,
                receiverAddress,
                amount
            )
        ).to.be.revertedWithCustomError(settlmentInstance, "AccessControlUnauthorizedAccount");
    });
    // it("Should deposited", async function () {
    //     const [sender, receiver] = await hre.ethers.getSigners();
    //     const { settlmentInstance, settlementDepositer } = await loadFixture(deploySettlementFixture)

    //     const toChainId = 2;
    //     const fromChainName = ""
    //     const toChainName = ""
    //     const btcTxId = Buffer.from("0xffffffff")
    //     const amount = 500

    //     const depositRequestTx = await settlmentInstance.connect(settlementDepositer).deposit_request(
    //         BigInt(chainId),
    //         BigInt(toChainId),
    //         fromChainName,
    //         toChainName,
    //         await sender.getAddress(),
    //         await receiver.getAddress(),
    //         amount,
    //         btcTxId
    //     );

    //     const depositReqeustTxRecipet = await depositRequestTx.wait();
    //     const depositReqeustTxId = depositReqeustTxRecipet.logs[0].args[0];

    //     const depositedTx = settlmentInstance.connect(settlementDepositer).deposited(
    //         depositReqeustTxId,
    //         BigInt(chainId),
    //         BigInt(toChainId),
    //         fromChainName,
    //         toChainName,
    //         btcTxId
    //     )
    //     const depositedRecipet = await depositRequestTx.wait();
    //     const depositedTxId = depositedRecipet.logs[0].args[0];

    //     await expect(depositedTx)
    //         .to.emit(settlmentInstance, 'Deposited')
    //         .withArgs(depositedTxId, await sender.getAddress(), await receiver.getAddress(), amount, chainId, toChainId, fromChainName, toChainName, btcTxId);
    // });

    // it("Should deposited with validator role", async function () {
    //     const [sender, receiver, validator] = await hre.ethers.getSigners();
    //     const { settlmentInstance, settlementManager, settlementDepositer } = await loadFixture(deploySettlementFixture)

    //     const toChainId = 2;
    //     const fromChainName = ""
    //     const toChainName = ""
    //     const btcTxId = Buffer.from("0xffffffff")
    //     const amount = 500

    //     await settlmentInstance.connect(settlementManager).add_validator(await validator.getAddress());

    //     const depositRequestTx = await settlmentInstance.connect(settlementDepositer).deposit_request(
    //         BigInt(chainId),
    //         BigInt(toChainId),
    //         fromChainName,
    //         toChainName,
    //         await sender.getAddress(),
    //         await receiver.getAddress(),
    //         amount,
    //         btcTxId
    //     );

    //     const depositReqeustTxRecipet = await depositRequestTx.wait();
    //     const depositReqeustTxId = depositReqeustTxRecipet.logs[0].args[0];

    //     const depositedTx = settlmentInstance.connect(validator).deposited(
    //         depositReqeustTxId,
    //         BigInt(chainId),
    //         BigInt(toChainId),
    //         fromChainName,
    //         toChainName,
    //         btcTxId
    //     )
    //     const depositedRecipet = await depositRequestTx.wait();
    //     const depositedTxId = depositedRecipet.logs[0].args[0];

    //     await expect(depositedTx)
    //         .to.emit(settlmentInstance, 'Deposited')
    //         .withArgs(depositedTxId, await sender.getAddress(), await receiver.getAddress(), amount, chainId, toChainId, fromChainName, toChainName, btcTxId);
    // });

    // it("Should deposited revert due bad role", async function () {
    //     const [sender, receiver] = await hre.ethers.getSigners();
    //     const { settlmentInstance, settlementDepositer } = await loadFixture(deploySettlementFixture)

    //     const toChainId = 2;
    //     const fromChainName = ""
    //     const toChainName = ""
    //     const btcTxId = Buffer.from("0xffffffff")
    //     const amount = 500

    //     const depositRequestTx = await settlmentInstance.connect(settlementDepositer).deposit_request(
    //         BigInt(chainId),
    //         BigInt(toChainId),
    //         fromChainName,
    //         toChainName,
    //         await sender.getAddress(),
    //         await receiver.getAddress(),
    //         amount,
    //         btcTxId
    //     );

    //     const depositReqeustTxRecipet = await depositRequestTx.wait();
    //     const depositReqeustTxId = depositReqeustTxRecipet.logs[0].args[0];

    //     // The deposited method only validator or DEPOSITER_ROLEs can be called.
    //     await expect(
    //         settlmentInstance.connect(sender).deposited(
    //             depositReqeustTxId,
    //             BigInt(chainId),
    //             BigInt(toChainId),
    //             fromChainName,
    //             toChainName,
    //             btcTxId
    //         )
    //     ).to.be.revertedWith("Invalid role");
    // });

    it("Chakra settlement should minted", async function () {
        const [validator1, validator2, validator3] = await hre.ethers.getSigners();
        const { extendERC20Instance, settlmentInstance, settlementDepositer, extendERC20Owner, settlementManager } = await loadFixture(deploySettlementFixture)

        const amount = 1000
        const btcTxId = hre.ethers.toBigInt(Buffer.from("7b09bfd0070ec50ba95640fcf078907a8ea1fd109e4979abbd073a34b2c2787e", 'hex'))

        const { receiver } = await sendDepositRequest(
            btcTxId,
            amount,
            settlmentInstance,
            settlementDepositer
        )

        await extendERC20Instance.connect(extendERC20Owner).add_owner(await settlmentInstance.getAddress());
        await settlmentInstance.connect(settlementManager).add_validator(await validator1.getAddress());
        await settlmentInstance.connect(settlementManager).add_validator(await validator2.getAddress());
        await settlmentInstance.connect(settlementManager).add_validator(await validator3.getAddress());

        const receiverAddress = await receiver.getAddress();
        const otherChainId = 2;
        const fromChainName = ""
        const toChainName = ""

        const tx1 = await settlmentInstance.connect(validator1).pre_mint(
            btcTxId,
            BigInt(chainId),
            BigInt(otherChainId),
            fromChainName,
            toChainName,
            receiverAddress,
            amount,
        );

        await expect(tx1)
            .to.emit(settlmentInstance, 'PreMint')
            .withArgs(
                btcTxId,
                receiverAddress,
                amount,
                chainId,
                otherChainId,
                fromChainName,
                toChainName,
                validator1.address
            );


        const tx2 = await settlmentInstance.connect(validator2).pre_mint(
            btcTxId,
            BigInt(chainId),
            BigInt(otherChainId),
            fromChainName,
            toChainName,
            await receiver.getAddress(),
            amount,
        );

        await expect(tx2)
            .to.emit(settlmentInstance, 'Minted')
            .withArgs(
                btcTxId,
                receiverAddress,
                amount,
                chainId,
                otherChainId,
                fromChainName,
                toChainName
            );

        expect(await extendERC20Instance.balanceOf(await receiver.getAddress())).to.equal(amount);
    });


    it("Chakra settlement should fail due to not exists transaction", async function () {
        const [validator1, validator2, validator3] = await hre.ethers.getSigners();
        const { extendERC20Instance, settlmentInstance, settlementDepositer, extendERC20Owner, settlementManager } = await loadFixture(deploySettlementFixture)

        const amount = 1000
        const btcTxId = hre.ethers.toBigInt(Buffer.from("7b09bfd0070ec50ba95640fcf078907a8ea1fd109e4979abbd073a34b2c2787e", 'hex'))

        const { receiver } = await sendDepositRequest(
            btcTxId,
            amount,
            settlmentInstance,
            settlementDepositer
        )

        await extendERC20Instance.connect(extendERC20Owner).add_owner(await settlmentInstance.getAddress());
        await settlmentInstance.connect(settlementManager).add_validator(await validator1.getAddress());
        await settlmentInstance.connect(settlementManager).add_validator(await validator2.getAddress());
        await settlmentInstance.connect(settlementManager).add_validator(await validator3.getAddress());

        const receiverAddress = await receiver.getAddress();
        const otherChainId = 2;
        const fromChainName = ""
        const toChainName = ""
        const badBtcTxId = hre.ethers.toBigInt(Buffer.from("6c09bfd0070ec50ba95640fcf078907a8ea1fd109e4979abbd073a34b2c2787e", 'hex'))

        await expect(settlmentInstance.connect(validator1).pre_mint(
            badBtcTxId,
            BigInt(chainId),
            BigInt(otherChainId),
            fromChainName,
            toChainName,
            receiverAddress,
            amount,
        )).to.be.revertedWith("Transaction does not exist");
    });

    it("Chakra settlement should fail due to undefined validator", async function () {
        const [validator1, validator2, validator3, validator4] = await hre.ethers.getSigners();
        const { extendERC20Instance, settlmentInstance, settlementDepositer, extendERC20Owner, settlementManager } = await loadFixture(deploySettlementFixture)

        const amount = 1000
        const btcTxId = hre.ethers.toBigInt(Buffer.from("7b09bfd0070ec50ba95640fcf078907a8ea1fd109e4979abbd073a34b2c2787e", 'hex'))

        const { receiver } = await sendDepositRequest(
            btcTxId,
            amount,
            settlmentInstance,
            settlementDepositer
        )

        await extendERC20Instance.connect(extendERC20Owner).add_owner(await settlmentInstance.getAddress());
        await settlmentInstance.connect(settlementManager).add_validator(await validator1.getAddress());
        await settlmentInstance.connect(settlementManager).add_validator(await validator2.getAddress());
        await settlmentInstance.connect(settlementManager).add_validator(await validator3.getAddress());

        const receiverAddress = await receiver.getAddress();
        const otherChainId = 2;
        const fromChainName = ""
        const toChainName = ""

        await expect(settlmentInstance.connect(validator4).pre_mint(
            btcTxId,
            BigInt(chainId),
            BigInt(otherChainId),
            fromChainName,
            toChainName,
            receiverAddress,
            amount,
        )).to.be.rejectedWith("Not validator");
    });

    it("Chakra settlement should fail due to not unequal amounts", async function () {
        const [validator1, validator2, validator3] = await hre.ethers.getSigners();
        const { extendERC20Instance, settlmentInstance, settlementDepositer, extendERC20Owner, settlementManager } = await loadFixture(deploySettlementFixture)

        // deposit_request 1000, but want mint 2000
        const amount = 1000
        const btcTxId = hre.ethers.toBigInt(Buffer.from("7b09bfd0070ec50ba95640fcf078907a8ea1fd109e4979abbd073a34b2c2787e", 'hex'))

        const { receiver } = await sendDepositRequest(
            btcTxId,
            amount,
            settlmentInstance,
            settlementDepositer
        )

        await extendERC20Instance.connect(extendERC20Owner).add_owner(await settlmentInstance.getAddress());
        await settlmentInstance.connect(settlementManager).add_validator(await validator1.getAddress());
        await settlmentInstance.connect(settlementManager).add_validator(await validator2.getAddress());
        await settlmentInstance.connect(settlementManager).add_validator(await validator3.getAddress());

        const receiverAddress = await receiver.getAddress();
        const otherChainId = 2;
        const fromChainName = ""
        const toChainName = ""

        await expect(settlmentInstance.connect(validator1).pre_mint(
            btcTxId,
            BigInt(chainId),
            BigInt(otherChainId),
            fromChainName,
            toChainName,
            receiverAddress,
            2000,
        )).to.be.revertedWith("Invalid mint amount");
    });

    it("Chakra settlement should not remint", async function () {
        const [validator1, validator2, validator3] = await hre.ethers.getSigners();
        const { extendERC20Instance, settlmentInstance, settlementDepositer, extendERC20Owner, settlementManager } = await loadFixture(deploySettlementFixture)

        // deposit_request 1000, but want mint 2000
        const amount = 1000
        const btcTxId = hre.ethers.toBigInt(Buffer.from("7b09bfd0070ec50ba95640fcf078907a8ea1fd109e4979abbd073a34b2c2787e", 'hex'))

        const { receiver } = await sendDepositRequest(
            btcTxId,
            amount,
            settlmentInstance,
            settlementDepositer
        )

        await extendERC20Instance.connect(extendERC20Owner).add_owner(await settlmentInstance.getAddress());
        await settlmentInstance.connect(settlementManager).add_validator(await validator1.getAddress());
        await settlmentInstance.connect(settlementManager).add_validator(await validator2.getAddress());
        await settlmentInstance.connect(settlementManager).add_validator(await validator3.getAddress());

        const receiverAddress = await receiver.getAddress();
        const otherChainId = 2;
        const fromChainName = ""
        const toChainName = ""

        await settlmentInstance.connect(validator1).pre_mint(
            btcTxId,
            BigInt(chainId),
            BigInt(otherChainId),
            fromChainName,
            toChainName,
            receiverAddress,
            amount,
        );

        const tx = await settlmentInstance.connect(validator2).pre_mint(
            btcTxId,
            BigInt(chainId),
            BigInt(otherChainId),
            fromChainName,
            toChainName,
            receiverAddress,
            amount,
        );

        await expect(tx)
            .to.emit(settlmentInstance, 'Minted')
            .withArgs(
                btcTxId,
                receiverAddress,
                amount,
                chainId,
                otherChainId,
                fromChainName,
                toChainName
            );

        await expect(settlmentInstance.connect(validator3).pre_mint(
            btcTxId,
            BigInt(chainId),
            BigInt(otherChainId),
            fromChainName,
            toChainName,
            receiverAddress,
            amount,
        )).to.be.revertedWith("Transaction already minted");
    });

    it("Chakra settlement should fail due to validator auth multiple times", async function () {
        const [validator1, validator2, validator3] = await hre.ethers.getSigners();
        const { extendERC20Instance, settlmentInstance, settlementDepositer, extendERC20Owner, settlementManager } = await loadFixture(deploySettlementFixture)

        // deposit_request 1000, but want mint 2000
        const amount = 1000
        const btcTxId = hre.ethers.toBigInt(Buffer.from("7b09bfd0070ec50ba95640fcf078907a8ea1fd109e4979abbd073a34b2c2787e", 'hex'))

        const { receiver } = await sendDepositRequest(
            btcTxId,
            amount,
            settlmentInstance,
            settlementDepositer
        )

        await extendERC20Instance.connect(extendERC20Owner).add_owner(await settlmentInstance.getAddress());
        await settlmentInstance.connect(settlementManager).add_validator(await validator1.getAddress());
        await settlmentInstance.connect(settlementManager).add_validator(await validator2.getAddress());
        await settlmentInstance.connect(settlementManager).add_validator(await validator3.getAddress());

        const receiverAddress = await receiver.getAddress();
        const otherChainId = 2;
        const fromChainName = ""
        const toChainName = ""

        await settlmentInstance.connect(validator1).pre_mint(
            btcTxId,
            BigInt(chainId),
            BigInt(otherChainId),
            fromChainName,
            toChainName,
            receiverAddress,
            amount,
        );

        await expect(settlmentInstance.connect(validator1).pre_mint(
            btcTxId,
            BigInt(chainId),
            BigInt(otherChainId),
            fromChainName,
            toChainName,
            receiverAddress,
            amount,
        )).to.be.revertedWith("Validator already authed");
    });

});
