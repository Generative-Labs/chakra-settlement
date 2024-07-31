// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ISettlement} from "contracts/interfaces/ISettlement.sol";
import {IERC20CodecV1} from "contracts/interfaces/IERC20CodecV1.sol";
import {IERC20Mint} from "contracts/interfaces/IERC20Mint.sol";
import {IERC20Burn} from "contracts/interfaces/IERC20Burn.sol";
import {ISettlementHandler} from "contracts/interfaces/ISettlementHandler.sol";
import {AddressCast} from "contracts/libraries/AddressCast.sol";
import {Message, PayloadType, CrossChainMsgStatus} from "contracts/libraries/Message.sol";
import {MessageV1Codec} from "contracts/libraries/MessageV1Codec.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BaseSettlementHandler} from "contracts/BaseSettlementHandler.sol";
import "contracts/libraries/ERC20Payload.sol";

contract ChakraSettlementHandler is BaseSettlementHandler, ISettlementHandler {
    mapping(string => mapping(uint256 => bool)) public handler_whitelist;

    /**
     * @dev The address of the codec contract
     */
    IERC20CodecV1 public codec;

    // Enum to represent transaction status
    enum TxStatus {
        Unknow,
        Pending,
        Minted,
        Burned,
        Failed
    }

    /**
     * @dev Checks if a handler is valid for a given chain
     * @param chain_name The name of the chain
     * @param handler The handler address
     * @return bool True if the handler is valid, false otherwise
     */
    function is_valid_handler(
        string memory chain_name,
        uint256 handler
    ) public view returns (bool) {
        return handler_whitelist[chain_name][handler];
    }

    /**
     * @dev Adds a handler to the whitelist for a given chain
     * @param chain_name The name of the chain
     * @param handler The handler address to add
     */
    function add_handler(
        string memory chain_name,
        uint256 handler
    ) external onlyOwner {
        handler_whitelist[chain_name][handler] = true;
    }

    /**
     * @dev Removes a handler from the whitelist for a given chain
     * @param chain_name The name of the chain
     * @param handler The handler address to remove
     */
    function remove_handler(
        string memory chain_name,
        uint256 handler
    ) external onlyOwner {
        handler_whitelist[chain_name][handler] = false;
    }

    /**
     * @dev Initializes the contract
     * @param _owner The owner address
     * @param _no_burn Flag to indicate if burning is disabled
     * @param _chain The chain name
     * @param _token The token address
     * @param _codec The codec address
     * @param _verifier The verifier address
     * @param _settlement The settlement address
     */
    function initialize(
        address _owner,
        bool _no_burn,
        string memory _chain,
        address _token,
        address _codec,
        address _verifier,
        address _settlement
    ) public initializer {
        // Initialize the base settlement handler
        _Settlement_handler_init(
            _owner,
            _no_burn,
            _token,
            _verifier,
            _chain,
            _settlement
        );
        codec = IERC20CodecV1(_codec);
    }

    /**
     * @dev Initiates a cross-chain ERC20 settlement
     * @param to_chain The destination chain
     * @param to_handler The destination handler
     * @param to_token The destination token
     * @param to The recipient address
     * @param amount The amount to transfer
     */
    function cross_chain_erc20_settlement(
        string memory to_chain,
        uint256 to_handler,
        uint256 to_token,
        uint256 to,
        uint256 amount
    ) external {
        require(amount > 0, "Amount must be greater than 0");
        require(to != 0, "Invalid to address");
        require(to_handler != 0, "Invalid to handler address");
        require(to_token != 0, "Invalid to token address");

        require(
            IERC20(token).balanceOf(msg.sender) >= amount,
            "Insufficient balance"
        );

        // transfer tokens
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        // Increment nonce for the sender
        nonce_manager[msg.sender] += 1;

        // Create a new cross chain msg id
        cross_chain_msg_id_counter += 1;
        uint256 cross_chain_msg_id = uint256(
            keccak256(
                abi.encodePacked(
                    cross_chain_msg_id_counter,
                    address(this),
                    msg.sender,
                    nonce_manager[msg.sender]
                )
            )
        );

        // Create a erc20 transfer payload
        ERC20TransferPayload memory payload = ERC20TransferPayload(
            ERC20Method.Transfer,
            AddressCast.to_uint256(msg.sender),
            to,
            AddressCast.to_uint256(token),
            to_token,
            amount
        );

        // Create a cross chain msg
        Message memory cross_chain_msg = Message(
            cross_chain_msg_id,
            PayloadType.ERC20,
            codec.encode_transfer(payload)
        );

        // Encode the cross chain msg
        bytes memory cross_chain_msg_bytes = MessageV1Codec.encode(
            cross_chain_msg
        );

        // Create a new cross chain tx
        uint256 txid = uint256(
            keccak256(
                abi.encodePacked(
                    chain,
                    to_chain,
                    msg.sender, // from address for settlement to calculate txid
                    address(this), //  from handler for settlement to calculate txid
                    to_handler,
                    nonce_manager[msg.sender]
                )
            )
        );

        // Save the cross chain tx
        create_cross_txs[txid] = CreatedCrossChainTx(
            txid,
            chain,
            to_chain,
            msg.sender,
            to,
            address(this),
            to_token,
            amount,
            CrossChainTxStatus.Pending
        );

        // Send the cross chain msg
        settlement.send_cross_chain_msg(
            to_chain,
            msg.sender,
            to_handler,
            PayloadType.ERC20,
            cross_chain_msg_bytes
        );

        emit CrossChainLocked(
            txid,
            msg.sender,
            to,
            chain,
            to_chain,
            address(this),
            to_token,
            amount
        );
    }

    /**
     * @dev Checks if the payload type is valid
     * @param payload_type The payload type to check
     * @return bool True if valid, false otherwise
     */
    function isValidPayloadType(
        PayloadType payload_type
    ) internal pure returns (bool) {
        return (payload_type == PayloadType.ERC20);
    }

    /**
     * @dev Receives a cross-chain message
     * @param from_chain The source chain
     * @param from_handler The source handler
     * @param payload_type The type of payload
     * @param payload The payload data
     * @return bool True if successful, false otherwise
     */
    function receive_cross_chain_msg(
        uint256 /**txid */,
        string memory from_chain,
        uint256 /**from_address */,
        uint256 from_handler,
        PayloadType payload_type,
        bytes calldata payload,
        uint8 /**sign type */,
        bytes calldata /**signaturs */
    ) external onlySettlement returns (bool) {
        //  from_handler need in whitelist
        if (is_valid_handler(from_chain, from_handler) == false) {
            return false;
        }

        bytes calldata msg_payload = MessageV1Codec.payload(payload);

        require(isValidPayloadType(payload_type), "Invalid payload type");

        if (payload_type == PayloadType.ERC20) {
            // Decode payload method
            ERC20Method method = codec.decode_method(msg_payload);

            // Cross chain transfer
            {
                if (method == ERC20Method.Transfer) {
                    // Decode transfer payload
                    ERC20TransferPayload memory transfer_payload = codec
                        .deocde_transfer(payload);

                    if (no_burn) {
                        require(
                            IERC20(token).balanceOf(address(this)) >=
                                transfer_payload.amount,
                            "Insufficient balance"
                        );

                        IERC20(token).transfer(
                            AddressCast.to_address(transfer_payload.to),
                            transfer_payload.amount
                        );
                    } else {
                        IERC20Mint(token).mint_to(
                            AddressCast.to_address(transfer_payload.to),
                            transfer_payload.amount
                        );
                    }

                    return true;
                }
            }
        }

        return false;
    }

    /**
     * @dev Receives a cross-chain callback
     * @param txid The transaction ID
     * @param from_chain The source chain
     * @param from_handler The source handler
     * @param status The status of the cross-chain message
     * @return bool True if successful, false otherwise
     */
    function receive_cross_chain_callback(
        uint256 txid,
        string memory from_chain,
        uint256 from_handler,
        CrossChainMsgStatus status,
        uint8 /* sign_type */, // validators signature type /  multisig or bls sr25519
        bytes calldata /* signatures */
    ) external onlySettlement returns (bool) {
        //  from_handler need in whitelist
        if (is_valid_handler(from_chain, from_handler) == false) {
            return false;
        }

        require(
            create_cross_txs[txid].status == CrossChainTxStatus.Pending,
            "invalid CrossChainTxStatus"
        );

        if (status == CrossChainMsgStatus.Success) {
            if (no_burn) {
                IERC20Burn(token).burn(create_cross_txs[txid].amount);
            }

            create_cross_txs[txid].status = CrossChainTxStatus.Settled;
        }

        if (status == CrossChainMsgStatus.Failed) {
            create_cross_txs[txid].status = CrossChainTxStatus.Failed;
        }

        return true;
    }
}
