// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ISettlement} from "contracts/interfaces/ISettlement.sol";
import {IERC20CodecV1} from "contracts/tests/IERC20CodecV1.t.sol";
import {ISettlementSignatureVerifier} from "contracts/interfaces/ISettlementSignatureVerifier.sol";
import {AddressCast} from "contracts/libraries/AddressCast.sol";
import {Message, PayloadType} from "contracts/libraries/Message.sol";
import {MessageV1Codec} from "contracts/libraries/MessageV1Codec.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "contracts/tests/ERC20Payload.t.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

abstract contract BaseSettlementHandler is OwnableUpgradeable, UUPSUpgradeable {
    using ECDSA for bytes32;

    enum CrossChainTxStatus {
        Unknow,
        Pending,
        Minted,
        Settled,
        Failed
    }

    event CrossChainLocked(
        uint256 indexed txid,
        address indexed from,
        uint256 indexed to,
        string from_chain,
        string to_chain,
        address from_token,
        uint256 to_token,
        uint256 amount,
        bytes payload
    );
    // =============== Contracts ============================================================
    bool public no_burn;
    /**
     * @dev The address of the token contract
     */
    address public token;

    /**
     * @dev The address of the verify contract
     */
    ISettlementSignatureVerifier public verifier;

    /**
     * @dev The address of the settlement contract
     */
    ISettlement public settlement;

    // =============== Storages ============================================================
    mapping(string => mapping(uint256 => bool)) public handler_whitelist;
    mapping(address => uint256) public nonce_manager;
    uint64 public cross_chain_msg_id_counter;
    /**
     * @dev The chain name
     */
    string public chain;

    event SentCrossSettlementMsg(
        uint256 txid,
        string from_chain,
        string to_chain,
        address from_handler,
        address to_handler,
        bytes payload
    );

    function _Settlement_handler_init(
        address _owner,
        bool _no_burn,
        address _token,
        address _verifier,
        string memory _chain,
        address _settlement
    ) public {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        settlement = ISettlement(_settlement);
        verifier = ISettlementSignatureVerifier(_verifier);
        no_burn = _no_burn;
        token = _token;
        chain = _chain;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

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
}
