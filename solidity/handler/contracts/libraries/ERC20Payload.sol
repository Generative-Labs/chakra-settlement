// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

enum ERC20Method {
    Unkown,
    Transfer,
    Arppvoe,
    TransferFrom,
    Mint,
    Burn
}

struct ERC20TransferPayload {
    ERC20Method method_id;
    uint256 from;
    uint256 to;
    uint256 from_token;
    uint256 to_token;
    uint256 amount;
}

struct ERC20ApprovePayload {
    ERC20Method method_id;
    uint256 spender;
    uint256 amount;
}

struct ERC20TransferFromPayload {
    ERC20Method method_id;
    uint256 from;
    uint256 to;
    uint256 amount;
}

struct ERC20MintPayload {
    ERC20Method method_id;
    uint256 account;
    uint256 amount;
}

struct ERC20BurnPayload {
    ERC20Method method_id;
    uint256 account;
    uint256 amount;
}
