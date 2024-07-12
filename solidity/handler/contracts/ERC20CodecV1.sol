// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20CodecV1} from "contracts/interfaces/IERC20CodecV1.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "contracts/libraries/ERC20Payload.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract ERC20CodecV1 is IERC20CodecV1, OwnableUpgradeable, UUPSUpgradeable {
    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    /**
     * @dev Encode transfer payload
     * @param _payload ERC20TransferPayload
     */
    function encode_transfer(
        ERC20TransferPayload memory _payload
    ) external pure returns (bytes memory encodedPaylaod) {
        encodedPaylaod = abi.encodePacked(
            _payload.method_id,
            _payload.from,
            _payload.to,
            _payload.from_token,
            _payload.to_token,
            _payload.amount
        );
    }

    /**
     * @dev Encode approve payload
     * @param _payload ERC20ApprovePayload
     */
    function encode_approve(
        ERC20ApprovePayload memory _payload
    ) external pure returns (bytes memory encodedPayload) {
        encodedPayload = abi.encodePacked(
            _payload.method_id,
            _payload.spender,
            _payload.amount
        );
    }

    /**
     * @dev Encode transfer from payload
     * @param _payload ERC20TransferFromPayload
     */
    function encode_transfer_from(
        ERC20TransferFromPayload memory _payload
    ) external pure returns (bytes memory encodedPayload) {
        encodedPayload = abi.encodePacked(
            _payload.method_id,
            _payload.from,
            _payload.to,
            _payload.amount
        );
    }

    /**
     * @dev Encode mint payload
     * @param _payload ERC20MintPayload
     */
    function encode_mint(
        ERC20MintPayload memory _payload
    ) external pure returns (bytes memory encodedPayload) {
        encodedPayload = abi.encodePacked(
            _payload.method_id,
            _payload.account,
            _payload.amount
        );
    }

    /**
     * @dev Encode burn payload
     * @param _payload ERC20BurnPayload
     */
    function encode_burn(
        ERC20BurnPayload memory _payload
    ) external pure returns (bytes memory encodedPayload) {
        encodedPayload = abi.encodePacked(
            _payload.method_id,
            _payload.account,
            _payload.amount
        );
    }

    /**
     * @dev Decode method id
     * @param _payload bytes
     */
    function decode_method(
        bytes calldata _payload
    ) external pure returns (ERC20Method method) {
        return ERC20Method(uint8(_payload[0]));
    }

    /**
     * @dev Decode transfer payload
     * @param _payload bytes
     */
    function deocde_transfer(
        bytes calldata _payload
    ) external pure returns (ERC20TransferPayload memory transferPayload) {
        transferPayload.method_id = ERC20Method(uint8(_payload[0]));
        transferPayload.from = abi.decode(_payload[1:33], (uint256));
        transferPayload.to = abi.decode(_payload[33:65], (uint256));
        transferPayload.from_token = abi.decode(_payload[65:97], (uint256));
        transferPayload.to_token = abi.decode(_payload[97:129], (uint256));
        transferPayload.amount = abi.decode(_payload[129:161], (uint256));
    }

    /**
     * @dev Decode approve payload
     * @param _payload bytes
     */
    function decode_approve(
        bytes calldata _payload
    ) external pure returns (ERC20ApprovePayload memory approvePayload) {
        approvePayload.method_id = ERC20Method(uint8(_payload[0]));
        approvePayload.spender = abi.decode(_payload[1:33], (uint256));
        approvePayload.amount = abi.decode(_payload[33:65], (uint256));
    }

    /**
     * @dev Decode tranfer from payload
     * @param _payload bytes
     */
    function decode_transfer_from(
        bytes calldata _payload
    )
        external
        pure
        returns (ERC20TransferFromPayload memory transferFromPayload)
    {
        transferFromPayload.method_id = ERC20Method(uint8(_payload[0]));
        transferFromPayload.from = abi.decode(_payload[1:33], (uint256));
        transferFromPayload.to = abi.decode(_payload[33:65], (uint256));
        transferFromPayload.amount = abi.decode(_payload[65:97], (uint256));
    }

    /**
     * @dev Decode mint payload
     * @param _payload bytes
     */
    function decode_mint(
        bytes calldata _payload
    ) external pure returns (ERC20MintPayload memory mintPayload) {
        mintPayload.method_id = ERC20Method(uint8(_payload[0]));
        mintPayload.account = abi.decode(_payload[1:33], (uint256));
        mintPayload.amount = abi.decode(_payload[33:65], (uint256));
    }

    /**
     * @dev Decode burn payload
     * @param _payload bytes
     */
    function decode_burn(
        bytes calldata _payload
    ) external pure returns (ERC20BurnPayload memory burnPayload) {
        burnPayload.method_id = ERC20Method(uint8(_payload[0]));
        burnPayload.account = abi.decode(_payload[1:33], (uint256));
        burnPayload.amount = abi.decode(_payload[33:65], (uint256));
    }
}
