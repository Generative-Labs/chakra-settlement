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
import {BTCV1Codec} from "contracts/libraries/BTCV1Codec.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BaseSettlementHandler} from "contracts/BaseSettlementHandler.sol";
import "contracts/libraries/ERC20Payload.sol";
import "contracts/libraries/BTCPayload.sol";

contract ChakraSettlementHandler is BaseSettlementHandler, ISettlementHandler {
    mapping(string => mapping(uint256 => bool)) public handler_whitelist;

    /**
     * @dev The address of the codec contract
     */
    IERC20CodecV1 public codec;
    /**
     * @notice The DEPOSIT_ROLE indicats that only this only can be call deposit_request.
     */
    bytes32 public constant DEPOSIT_ROLE = keccak256("DEPOSIT_ROLE");
    mapping(bytes32 => WithdrawTx) public withdraw_req_maps;

    enum TxStatus {
        Unknow,
        Pending,
        Minted,
        Burned,
        Failed
    }

    event WithdrawLocked(
        bytes32 indexed withdrawTxID,
        address indexed from,
        string to,
        uint256 amount
    );

    struct WithdrawTx {
        uint256 btc_txid;
        string from_chain;
        string to_chain;
        address from;
        string to;
        address from_handler;
        uint256 amount;
        TxStatus status;
    }

    function is_valid_handler(
        string memory chain_name,
        uint256 handler
    ) public view returns (bool) {
        return handler_whitelist[chain_name][handler];
    }

    function add_handler(
        string memory chain_name,
        uint256 handler
    ) external onlyOwner {
        handler_whitelist[chain_name][handler] = true;
    }

    function remove_handler(
        string memory chain_name,
        uint256 handler
    ) external onlyOwner {
        handler_whitelist[chain_name][handler] = false;
    }

    function initialize(
        address _owner,
        bool _no_burn,
        string memory _chain,
        address _token,
        address _codec,
        address _verifier,
        address _settlement,
        address[] memory _depositers
    ) public initializer {
        for (uint256 i = 0; i < _depositers.length; i++) {
            _grantRole(DEPOSIT_ROLE, _depositers[i]);
        }

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

        // Create a new cross chain tx
        uint256 txid = uint256(
            keccak256(
                abi.encodePacked(
                    chain,
                    to_chain,
                    msg.sender,
                    nonce_manager[msg.sender],
                    to,
                    amount
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

    function isValidPayloadType(
        PayloadType payload_type
    ) internal pure returns (bool) {
        return (payload_type == PayloadType.ERC20 ||
            payload_type == PayloadType.BTCDeposit ||
            payload_type == PayloadType.BTCWithdraw);
    }

    function receive_cross_chain_msg(
        uint256  txid ,
        string memory from_chain,
        uint256  from_address ,
        uint256 from_handler,
        PayloadType payload_type,
        bytes calldata payload,
        uint8  sign_type ,
        bytes calldata  signatures 
    ) external onlySettlement returns (bool) {
        //  from_handler need in whitelist
        if (is_valid_handler(from_chain, from_handler) == false) {
            return false;
        }

        bytes calldata msg_payload = MessageV1Codec.payload(payload);

        require(isValidPayloadType(payload_type), "Invalid payload type");

        if (payload_type == PayloadType.BTCDeposit) {
            BTCPayloadInfo memory _info = BTCV1Codec.decode(msg_payload);

            IERC20Mint(token).mint_to(
                AddressCast.to_address(_info.addr),
                _info.amount
            );
            return true;
        }

        if (payload_type == PayloadType.BTCWithdraw) {
            BTCPayloadInfo memory _info = BTCV1Codec.decode(msg_payload);

            IERC20Burn(token).burn_from(address(this), _info.amount);
            withdraw_req_maps[_info.txid].status = TxStatus.Burned;

            return true;
        }

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

    function deposit_request(
        uint256 btc_txid,
        string calldata btc_address,
        address receive_address,
        uint256 amount
    ) external onlyRole(DEPOSIT_ROLE) {
        uint256 msgid = uint256(
            keccak256(
                abi.encodePacked(btc_txid, btc_address, receive_address, amount)
            )
        );

        bytes memory deposit_bytes = BTCV1Codec.encode(
            btc_txid,
            0, // init txid
            btc_address,
            AddressCast.to_uint256(receive_address),
            amount
        );

        Message memory btc_deposit_msg = Message(
            msgid,
            PayloadType.BTCDeposit,
            deposit_bytes
        );

        settlement.send_cross_chain_msg(
            chain,
            msg.sender,
            AddressCast.to_uint256(address(this)),
            PayloadType.BTCDeposit,
            MessageV1Codec.encode(btc_deposit_msg)
        );
    }

    function withdraw_request(
        string calldata btc_address,
        uint256 amount
    ) external {
        require(
            IERC20(token).balanceOf(msg.sender) >= amount,
            "Insufficient balance"
        );

        require(
            IERC20(token).allowance(msg.sender, address(this)) >= amount,
            "Now approved"
        );

        IERC20(token).transferFrom(msg.sender, address(this), amount);

        bytes32 withdrawTxID = keccak256(
            abi.encodePacked(
                "chakra",
                "btc",
                msg.sender,
                btc_address,
                address(this),
                amount
            )
        );

        withdraw_req_maps[withdrawTxID] = WithdrawTx(
            0, // init btc txid
            "chakra",
            "btc",
            msg.sender,
            btc_address,
            address(this),
            amount,
            TxStatus.Pending
        );

        emit WithdrawLocked(withdrawTxID, msg.sender, btc_address, amount);
    }

    function burn_request(
        bytes32 withdrawTxID,
        uint256 btc_txid
    ) external onlyRole(DEPOSIT_ROLE) {
        WithdrawTx memory result = withdraw_req_maps[withdrawTxID];
        require(result.from != address(0), "Invalid withdrawTxID");

        require(
            IERC20(token).balanceOf(address(this)) >= result.amount,
            "Insufficient balance"
        );

        require(
            withdraw_req_maps[withdrawTxID].status == TxStatus.Pending,
            "Burn request transaction already exists"
        );

        withdraw_req_maps[withdrawTxID].btc_txid = btc_txid;

        bytes memory _bytes = BTCV1Codec.encode(
            btc_txid,
            withdrawTxID,
            result.to,
            AddressCast.to_uint256(result.from),
            result.amount
        );

        uint256 msgid = uint256(
            keccak256(
                abi.encodePacked(
                    btc_txid,
                    withdrawTxID,
                    result.to,
                    result.from,
                    result.amount
                )
            )
        );

        Message memory _msg = Message(msgid, PayloadType.BTCWithdraw, _bytes);

        settlement.send_cross_chain_msg(
            chain,
            msg.sender,
            AddressCast.to_uint256(address(this)),
            PayloadType.BTCWithdraw,
            MessageV1Codec.encode(_msg)
        );
    }
}
