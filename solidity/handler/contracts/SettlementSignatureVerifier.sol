// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ISettlementSignatureVerifier} from "contracts/interfaces/ISettlementSignatureVerifier.sol";
import {AddressCast} from "contracts/libraries/AddressCast.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract SettlementSignatureVerifier is
    ISettlementSignatureVerifier,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using ECDSA for bytes32;

    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function verify(
        bytes32 msgHash,
        bytes calldata signature,
        address[] calldata signers,
        uint8 sign_type
    ) external pure returns (bool) {
        if (sign_type == 0) {
            return verifyECDSA(msgHash, signature, signers);
        } else if (sign_type == 1) {
            return verifyBLS(msgHash, signature, signers);
        } else {
            return false;
        }
    }

    function verifyECDSA(
        bytes32 msgHash,
        bytes calldata signature,
        address[] calldata signers
    ) internal pure returns (bool) {
        require(
            signature.length % 65 == 0,
            "Signature length must be a multiple of 65"
        );

        bytes32 signed_message_hash = MessageHashUtils.toEthSignedMessageHash(
            msgHash
        );

        uint256 i = 0;
        uint256 j = 0;
        uint256 len = signature.length;

        while (i < len) {
            bytes memory sig = signature[i:65];
            i += 65;
            if (signed_message_hash.recover(sig) != signers[j]) {
                return false;
            }
            j++;
        }

        return true;
    }

    function verifyBLS(
        bytes32 /* msgHash */,
        bytes memory /* signaturs */,
        address[] memory /* signers */
    ) internal pure returns (bool) {
        return true;
    }
}
