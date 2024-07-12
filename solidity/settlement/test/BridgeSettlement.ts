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
        const [deployer, settlementOwner, settlementManager, extendERC20Owner, tokenOwner, tokenMinter, tokenBuner] = await hre.ethers.getSigners();
        const ChakraBTC = await hre.ethers.getContractFactory("ChakraBTC");
        const chakraBTCInstance = await hre.upgrades.deployProxy(ChakraBTC, [await tokenOwner.getAddress(), ckrBTCDecimals]);

        const ExtendERC20 = await hre.ethers.getContractFactory("ExtendERC20");
        const extendERC20Instance = await hre.upgrades.deployProxy(ExtendERC20, [await extendERC20Owner.getAddress(), await tokenMinter.getAddress(), await tokenOwner.getAddress(), await chakraBTCInstance.getAddress()]);


        const Settlement = await hre.ethers.getContractFactory("BridgeSettlement");
        const settlmentInstance = await hre.upgrades.deployProxy(Settlement, [await settlementOwner.getAddress(), [await settlementManager.getAddress()], BigInt(chainId), await extendERC20Instance.getAddress(), BigInt(requiredValidators)]);
        return { chakraBTCInstance, extendERC20Instance, settlmentInstance, deployer, extendERC20Owner, settlementOwner, settlementManager, tokenOwner, tokenMinter, tokenBuner }
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

    it("Bridge settlement should managed validators correctly", async function () {
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

    it("Bridge settlement should pre-deposit with lock", async function () {
        const [sender, receiver] = await hre.ethers.getSigners();
        const { chakraBTCInstance, extendERC20Instance, settlmentInstance, tokenMinter } = await loadFixture(deploySettlementFixture)



        const mintSenderAmount = 1000000;
        const approveSettlementAmount = 1000;
        await chakraBTCInstance.connect(tokenMinter).mint(await sender.getAddress(), mintSenderAmount);
        await chakraBTCInstance.connect(sender).approve(await settlmentInstance.getAddress(), approveSettlementAmount);

        const btcTxId = hre.ethers.toBigInt(Buffer.from("7b09bfd0070ec50ba95640fcf078907a8ea1fd109e4979abbd073a34b2c2787e", 'hex'))
        const toChainId = 2;
        const fromChainName = ""
        const toChainName = ""
        const amount = 500;
        const settlmentContractAddress = await settlmentInstance.getAddress();
        const senderAddress = await sender.getAddress();
        const receiverAddress = await receiver.getAddress();
        const tx = await settlmentInstance.connect(sender).pre_deposit(
            btcTxId,
            BigInt(chainId),
            BigInt(toChainId),
            fromChainName,
            toChainName,
            receiverAddress,
            amount,
            false,
        );


        // Check that the token locked to the settlement contract
        expect(await extendERC20Instance.balanceOf(settlmentContractAddress)).to.equal(amount);
        expect(await extendERC20Instance.allowance(senderAddress, settlmentContractAddress)).to.equal(approveSettlementAmount - amount);
        expect(await extendERC20Instance.balanceOf(senderAddress)).to.equal(mintSenderAmount - amount);

        // Check that event is emitted
        await expect(tx)
            .to.emit(settlmentInstance, 'PreDeposit')
            .withArgs(
                btcTxId,
                senderAddress,
                receiverAddress,
                amount,
                chainId,
                toChainId,
                fromChainName,
                toChainName,
                false
            );
    });

    it("Bridge settlement should pre-deposit with burn", async function () {
        const [sender, receiver] = await hre.ethers.getSigners();
        const { chakraBTCInstance, extendERC20Instance, extendERC20Owner, settlmentInstance, tokenMinter } = await loadFixture(deploySettlementFixture)



        const mintSenderAmount = 1000000;
        await extendERC20Instance.connect(extendERC20Owner).add_owner(await settlmentInstance.getAddress());
        await chakraBTCInstance.connect(tokenMinter).mint(await sender.getAddress(), mintSenderAmount);

        const btcTxId = hre.ethers.toBigInt(Buffer.from("7b09bfd0070ec50ba95640fcf078907a8ea1fd109e4979abbd073a34b2c2787e", 'hex'))
        const toChainId = 2;
        const fromChainName = ""
        const toChainName = ""
        const amount = 500;
        const settlmentContractAddress = await settlmentInstance.getAddress();
        const senderAddress = await sender.getAddress();
        const receiverAddress = await receiver.getAddress();
        const tx = await settlmentInstance.connect(sender).pre_deposit(
            btcTxId,
            BigInt(chainId),
            BigInt(toChainId),
            fromChainName,
            toChainName,
            receiverAddress,
            amount,
            true,
        );


        // Check that the token bruned correctly
        expect(await extendERC20Instance.balanceOf(settlmentContractAddress)).to.equal(0);
        expect(await extendERC20Instance.balanceOf(senderAddress)).to.equal(mintSenderAmount - amount);
        expect(await extendERC20Instance.totalSupply()).to.equal(mintSenderAmount - amount);

        // Check that event is emitted
        await expect(tx)
            .to.emit(settlmentInstance, 'PreDeposit')
            .withArgs(
                btcTxId,
                senderAddress,
                receiverAddress,
                amount,
                chainId,
                toChainId,
                fromChainName,
                toChainName,
                true
            );
    });
});
