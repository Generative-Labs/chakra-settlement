import { expect } from "chai";
import {
    loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";

import hre from "hardhat";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { keccak256 } from "ethers";

describe("ExtendERC20", function () {
    const token: string = "Chakra BTC";
    const symbol: string = "ckrBTC";
    const decimals = 8

    async function deployERC20Fixture() {
        const [deployer, tokeOnwner, owner, minter, burner] = await hre.ethers.getSigners();
        const ChakraBTC = await hre.ethers.getContractFactory("ChakraBTC");
        const chakraBTCInstance = await hre.upgrades.deployProxy(ChakraBTC, [await tokeOnwner.getAddress(), decimals]);

        const ExtendERC20 = await hre.ethers.getContractFactory("ExtendERC20");
        const instance = await hre.upgrades.deployProxy(ExtendERC20, [await owner.getAddress(), await minter.getAddress(), await burner.getAddress(), await chakraBTCInstance.getAddress()]);
        return { chakraBTCInstance, instance, deployer, tokeOnwner, owner, minter, burner }
    }

    it('Should upgrade to version 2', async () => {
        const { instance, deployer, owner, minter, burner } = await loadFixture(deployERC20Fixture);

        const instanceV2 = await hre.ethers.getContractFactory("ExtendERC20V2");

        const upgraded = await hre.upgrades.upgradeProxy(await instance.getAddress(), instanceV2.connect(owner));

        const upgraded_owner = await upgraded.owner();
        expect(upgraded_owner.toString()).to.equal(await owner.getAddress());

        expect(await upgraded.version()).to.equal(2);
    });


    it("Should initialize correctly", async function () {
        const { instance, deployer, owner, minter, burner } = await loadFixture(deployERC20Fixture)

        // Check that the relevant roles are correctly initialized
        expect(await instance.hasRole(await instance.MINTER_ROLE(), minter.address)).to.equal(true);
        expect(await instance.hasRole(await instance.BURNER_ROLE(), burner.address)).to.equal(true);
        expect(await instance.owner()).to.equal(owner.address);

        // Check that the token is properly initialized
        expect(await instance.balanceOf(owner.address)).to.equal(0);
        expect(await instance.balanceOf(minter.address)).to.equal(0);
        expect(await instance.balanceOf(burner.address)).to.equal(0);
        expect(await instance.name()).to.equal(token);
        expect(await instance.symbol()).to.equal(symbol);
        expect(await instance.decimals()).to.equal(decimals);

        const [a] = await hre.ethers.getSigners();
        // Check that deployer and owner can't do mint and burn
        await expect(
            instance.connect(deployer).mint_to(a.address, 100)
        ).to.be.revertedWithCustomError(instance, "AccessControlUnauthorizedAccount")
        await expect(
            instance.connect(deployer).burn_from(a.address, 100)
        ).to.be.revertedWithCustomError(instance, "AccessControlUnauthorizedAccount")
        await expect(
            instance.connect(owner).mint_to(a.address, 100)
        ).to.be.revertedWithCustomError(instance, "AccessControlUnauthorizedAccount")
        await expect(
            instance.connect(owner).burn_from(a.address, 100)
        ).to.be.revertedWithCustomError(instance, "AccessControlUnauthorizedAccount")

        // Check minter and burner works
        await instance.connect(minter).mint_to(a.address, 100)
        expect(await instance.balanceOf(a.address)).to.equal(100);
        await instance.connect(burner).burn_from(a.address, 50)
        expect(await instance.balanceOf(a.address)).to.equal(50);
    });

    it("Should add and remove owner correctly", async function () {
        let utf8Encode = new TextEncoder();
        let role_minter = keccak256(utf8Encode.encode("MINTER_ROLE"));
        let role_burner = keccak256(utf8Encode.encode("BURNER_ROLE"));

        const [otherAccount, a] = await hre.ethers.getSigners();
        const { instance, deployer, owner, minter, burner } = await loadFixture(deployERC20Fixture)
        // Owner can add and remove
        await instance.connect(owner).add_owner(otherAccount.address);
        expect(await instance.hasRole(role_minter, otherAccount.address)).to.equal(true);
        expect(await instance.hasRole(role_burner, otherAccount.address)).to.equal(true);

        await instance.connect(owner).remove_owner(otherAccount.address);
        expect(await instance.hasRole(role_minter, otherAccount.address)).to.equal(false);
        expect(await instance.hasRole(role_burner, otherAccount.address)).to.equal(false);

        // Only onwer can add, remove and transfer ownership
        await expect(
            instance.connect(otherAccount).add_owner(a.address)
        ).to.be.revertedWithCustomError(instance, "OwnableUnauthorizedAccount")
        await expect(
            instance.connect(otherAccount).remove_owner(a.address)
        ).to.be.revertedWithCustomError(instance, "OwnableUnauthorizedAccount")
        await expect(
            instance.connect(otherAccount).transferOwnership(a)
        ).to.be.revertedWithCustomError(instance, "OwnableUnauthorizedAccount")

        // After transfer ownership, other account can add and remove
        await instance.connect(owner).transferOwnership(otherAccount)
        const newOwner = await instance.owner();
        expect(newOwner.toString()).to.equal(otherAccount.address)

        await instance.connect(otherAccount).add_owner(a.address)
        expect(await instance.hasRole(role_minter, a.address)).to.equal(true);
        expect(await instance.hasRole(role_burner, a.address)).to.equal(true);

        await instance.connect(otherAccount).remove_owner(a.address)
        expect(await instance.hasRole(role_minter, a.address)).to.equal(false);
        expect(await instance.hasRole(role_burner, a.address)).to.equal(false);

        // Again transfer ownership should error
        await expect(
            instance.connect(owner).transferOwnership(otherAccount)
        ).to.be.revertedWithCustomError(instance, "OwnableUnauthorizedAccount")
    });

    it("Should mint and burn correctly", async function () {
        const [otherAccount, a] = await hre.ethers.getSigners();
        const { instance, owner } = await loadFixture(deployERC20Fixture)
        await instance.connect(owner).add_owner(otherAccount.address);


        await instance.connect(otherAccount).mint_to(a.address, 100);
        expect(await instance.balanceOf(a.address)).to.equal(100);
        await instance.connect(otherAccount).burn_from(a.address, 50);
        expect(await instance.balanceOf(a.address)).to.equal(50);

        // After remove owner, it should error
        await instance.connect(owner).remove_owner(otherAccount)
        await expect(
            instance.connect(otherAccount).mint_to(a.address, 100)
        ).to.be.reverted
        await expect(
            instance.connect(otherAccount).burn_from(a.address, 50)
        ).to.be.reverted
    });
});
