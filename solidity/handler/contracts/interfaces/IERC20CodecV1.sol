// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "contracts/libraries/ERC20Payload.sol";

interface IERC20CodecV1 {
    // transfer
    function encode_transfer(
        ERC20TransferPayload memory payload
    ) external pure returns (bytes memory);

    // approve
    function encode_approve(
        ERC20ApprovePayload memory payload
    ) external pure returns (bytes memory);

    // TransferFrom
    function encode_transfer_from(
        ERC20TransferFromPayload memory payload
    ) external pure returns (bytes memory);

    // Mint
    function encode_mint(
        ERC20MintPayload memory paylaod
    ) external pure returns (bytes calldata);

    // Burn
    function encode_burn(
        ERC20BurnPayload memory payload
    ) external pure returns (bytes memory);

    // Decode method id
    function decode_method(
        bytes calldata payload
    ) external pure returns (ERC20Method);

    // Decode transfer
    function deocde_transfer(
        bytes calldata payload
    ) external pure returns (ERC20TransferPayload memory);

    // Decode approve
    function decode_approve(
        bytes calldata payload
    ) external pure returns (ERC20ApprovePayload memory);

    // Decode transfer from
    function decode_transfer_from(
        bytes calldata payload
    ) external pure returns (ERC20TransferFromPayload memory);

    // Decode mint
    function decode_mint(
        bytes calldata payload
    ) external pure returns (ERC20MintPayload memory);

    // Decode burn
    function decode_burn(
        bytes calldata payload
    ) external pure returns (ERC20BurnPayload memory);
}

// struct ERC20Data {
//     bytes32 method_id;
//     uint256 txid;
//     bytes32 from;
//     uint256 to;
//     bytes32 from_token;
//     uint256 to_token;
//     uint256 amount;
// }

// bytes -> Vec<Felt256> -> Cairo

// erc20 codec -> address
// erc721 codec ->address

// custom codec -> register(address, abi) -> record

// settlement -> handler -> codec (address) <-> data
