// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Message, PayloadType, CrossChainMsgStatus} from "contracts/libraries/Message.sol";
import {MessageV1Codec} from "contracts/libraries/MessageV1Codec.sol";
import {AddressCast} from "contracts/libraries/AddressCast.sol";
import {IERC20CodecV1} from "contracts/tests/IERC20CodecV1.t.sol";
import "contracts/tests/ERC20Payload.t.sol";

contract MessageLibTest {
    function encode_erc20_settlement_message(
        uint256 msg_id,
        address sender,
        address codec,
        address token,
        uint256 to_token,
        uint256 to,
        uint256 amount
    ) external pure returns (bytes memory cross_chain_msg_bytes) {
        // Create a erc20 transfer payload
        ERC20TransferPayload memory payload = ERC20TransferPayload(
            ERC20Method.Transfer,
            AddressCast.to_uint256(sender),
            to,
            AddressCast.to_uint256(token),
            to_token,
            amount
        );

        // Create a cross chain msg
        Message memory cross_chain_msg = Message(
            msg_id,
            PayloadType.ERC20,
            IERC20CodecV1(codec).encode_transfer(payload)
        );

        cross_chain_msg_bytes = MessageV1Codec.encode(cross_chain_msg);
    }

    function encode_cross_chain_message_hash(
        uint256 txid,
        string memory from_chain,
        uint256 from_address,
        uint256 from_handler,
        address to_handler,
        bytes calldata payload
    ) external pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    txid,
                    from_chain,
                    from_address,
                    from_handler,
                    to_handler,
                    keccak256(payload)
                )
            );
    }
}
