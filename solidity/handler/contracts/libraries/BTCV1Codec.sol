// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BTCPayloadInfo} from "contracts/libraries/BTCPayload.sol";

library BTCV1Codec {
    function encode(
        uint256 btcTxid,
        bytes32 txid,
        string memory btcAddr,
        uint256 addr,
        uint256 amount
    ) internal pure returns (bytes memory) {
        return abi.encode(btcTxid, txid, btcAddr, addr, amount);
    }

    function decode(
        bytes calldata _payload
    ) internal pure returns (BTCPayloadInfo memory result) {
        (
            result.btcTxid,
            result.txid,
            result.btcAddr,
            result.addr,
            result.amount
        ) = abi.decode(_payload, (uint256, bytes32, string, uint256, uint256));
    }
}
