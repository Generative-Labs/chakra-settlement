// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


struct BTCPayloadInfo {
    uint256 btcTxid;
    bytes32 txid;  // for btc withdraw unique id
    string btcAddr; // btc address
    uint256 addr; //  wallet address
    uint256 amount;
}
