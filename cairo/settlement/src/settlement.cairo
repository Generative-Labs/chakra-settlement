use starknet::ContractAddress;

#[starknet::contract]
mod ChakraSettlement {
    use openzeppelin::access::ownable::interface::OwnableABI;
    use core::array::SpanTrait;
    use core::option::OptionTrait;
    use core::array::ArrayTrait;
    use core::traits::Into;
    use core::ecdsa::{check_ecdsa_signature, recover_public_key};
    use core::box::BoxTrait;
    use core::starknet::event::EventEmitter;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::ClassHash;
    use core::num::traits::Zero;
    use starknet::ContractAddress;
    use starknet::{get_caller_address, get_contract_address, get_tx_info, get_block_timestamp};
    use core::hash::LegacyHash;
    use settlement_cairo::interfaces::{IHandlerDispatcher, IHandlerDispatcherTrait,IChakraSettlement, ReceivedTx, CreatedTx};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // The status of Cross Chain Message Status
    pub mod CrossChainMsgStatus {
        pub const UNKNOW: u8 = 0;
        pub const PENDING: u8 = 1;
        pub const SUCCESS: u8 = 2;
        pub const FAILED: u8 = 3;
    }


    // The type of Cross Chain Message Payload
    pub mod CrossChainMsgPayloadType {
        pub const RAW: u8 = 0;
        pub const BTCDeposit: u8 = 1;
        pub const BTCStake: u8 = 2;
        pub const BTCUnStake: u8 = 3;
        pub const ERC20: u8 = 4;
        pub const ERC721: u8 = 5;
    }


    pub mod Errors {
        pub const NOT_OWNER: felt252 = 'Caller is not the owner';
        pub const NOT_MANAGER: felt252 = 'Caller is not a manager';
        pub const SAME_VALUE: felt252 = 'value same as you submited';
        pub const ALREADY_MANAGER: felt252 = 'Caller is a manager already';
        pub const NOT_VALIDATOR: felt252 = 'Caller is not a validator';
        pub const ALREADY_VALIDATOR: felt252 = 'Caller is a validator already';
        pub const NOT_PENDING_OWNER: felt252 = 'Caller is not the pending owner';
        pub const ZERO_ADDRESS_CALLER: felt252 = 'Caller is the zero address';
        pub const ZERO_ADDRESS_OWNER: felt252 = 'New owner is the zero address';
        pub const ALREADY_AUTH: felt252 = 'do not auth again';
        pub const HANDLER_NOT_ALLOWED: felt252 = 'handler not allowed to call me';
        pub const FAILED_TO_SET_CHAIN_NAME: felt252 = 'failed to set chain name';
    }


    // Ownable Mixin
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        chakra_validators_pubkey: LegacyMap<felt252, u8>,
        chakra_managers: LegacyMap<ContractAddress, u8>,
        // storage the txs which received
        received_tx:LegacyMap<u256, ReceivedTx>,
        // storage the txs which created
        created_tx:LegacyMap<felt252, CreatedTx>,
        chain_name:felt252,
        required_validators_num: u32,
        tx_count: u256
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        ManagerAdded: ManagerAdded,
        ManagerRemoved: ManagerRemoved,
        ValidatorAdded: ValidatorAdded,
        ValidatorRemoved: ValidatorRemoved,
        CrossChainMsg: CrossChainMsg,
        CrossChainHandleResult: CrossChainHandleResult,
        CrossChainResult: CrossChainResult
    }


    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct CrossChainMsg {
        #[key]
        pub cross_chain_settlement_id: felt252,
        #[key]
        pub from_address: ContractAddress,
        pub from_chain: felt252,
        pub from_handler: ContractAddress,
        pub to_chain: felt252,
        pub to_handler: u256,
        pub payload_type: u8,
        pub payload: Array<u8>
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct CrossChainHandleResult {
        #[key]
        pub cross_chain_settlement_id: u256,
        pub from_chain: felt252,
        pub from_handler: ContractAddress,
        pub to_chain: felt252,
        pub to_handler: u256,
        pub cross_chain_msg_status: u8,
        pub payload_type: u8,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct CrossChainResult {
        #[key]
        pub cross_chain_settlement_id: felt252,
        pub from_address: ContractAddress,
        pub from_chain: felt252,
        pub from_handler: ContractAddress,
        pub to_chain: felt252,
        pub to_handler: u256,
        pub cross_chain_msg_status: u8,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct ManagerAdded {
        #[key]
        pub operator: ContractAddress,
        pub new_manager: ContractAddress,
        pub added_at: u64
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct ManagerRemoved {
        #[key]
        pub operator: ContractAddress,
        pub old_manager: ContractAddress,
        pub removed_at: u64
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct ValidatorAdded {
        #[key]
        pub operator: ContractAddress,
        pub new_validator: felt252,
        pub added_at: u64
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct ValidatorRemoved {
        #[key]
        pub operator: ContractAddress,
        pub old_validator: felt252,
        pub removed_at: u64
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, chain_name: felt252) {
        self.ownable.initializer(owner);
        self.chakra_managers.write(owner, 1);
        self.chain_name.write(chain_name);
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        // validate signatures should > required_validators_num
        fn check_chakra_signatures(
            self: @ContractState, message_hash: felt252, signatures: Array<(felt252, felt252, bool)>
        ){
            let mut pass_count = 0;
            let mut i = 0;
            loop {
                if i > signatures.len()-1{
                    break;
                }
                let (r,s,y) = * signatures.at(i);
                let pub_key: felt252 = recover_public_key(message_hash,r,s,y).unwrap();
                if self.chakra_validators_pubkey.read(pub_key) > 0{
                    pass_count += 1;
                }
                i += 1;
            };
            assert(pass_count >= self.required_validators_num.read(), 'Not enough validate signatures');
        }
    }

    #[abi(embed_v0)]
    impl ChakraSettlementImpl of IChakraSettlement<ContractState> {
        fn get_signature_pub_key(self: @ContractState, message_hash: felt252, r: felt252, s:felt252, y: bool) -> felt252{
            return recover_public_key(message_hash,r,s,y).unwrap();
        }
        fn set_required_validators_num(ref self: ContractState, new_num: u32) -> u32 {
            let caller = get_caller_address();
            assert(self.chakra_managers.read(caller) == 1, Errors::NOT_MANAGER);
            self.required_validators_num.write(new_num);
            return self.required_validators_num.read();
        }

        fn view_required_validators_num(self: @ContractState) -> u32 {
            return self.required_validators_num.read();
        }

        // Validators related operations

        fn add_validator(ref self: ContractState, new_validator: felt252) -> bool {
            let caller = get_caller_address();
            assert(self.chakra_managers.read(caller) == 1, Errors::NOT_MANAGER);
            assert(self.chakra_validators_pubkey.read(new_validator) == 0, Errors::ALREADY_VALIDATOR);
            self.chakra_validators_pubkey.write(new_validator, 1);
            self
                .emit(
                    ValidatorAdded {
                        operator: caller,
                        new_validator: new_validator,
                        added_at: get_block_timestamp()
                    }
                );
            return self.chakra_validators_pubkey.read(new_validator) == 1;
        }
        fn remove_validator(ref self: ContractState, old_validator: felt252) -> bool {
            let caller = get_caller_address();
            assert(self.chakra_managers.read(caller) == 1, Errors::NOT_MANAGER);
            assert(self.chakra_validators_pubkey.read(old_validator) == 1, Errors::NOT_VALIDATOR);
            self.chakra_validators_pubkey.write(old_validator, 0);
            self
                .emit(
                    ValidatorRemoved {
                        operator: caller,
                        old_validator: old_validator,
                        removed_at: get_block_timestamp()
                    }
                );
            return self.chakra_validators_pubkey.read(old_validator) == 0;
        }

        fn is_validator(self: @ContractState, validator: felt252) -> bool {
            return self.chakra_validators_pubkey.read(validator) == 1;
        }

        // Managers related operations

        fn add_manager(ref self: ContractState, new_manager: ContractAddress) -> bool {
            let caller = get_caller_address();
            assert(self.chakra_managers.read(caller) == 1, Errors::NOT_MANAGER);
            assert(caller != new_manager, Errors::ALREADY_MANAGER);
            self.chakra_managers.write(new_manager, 1);
            self
                .emit(
                    ManagerAdded {
                        operator: caller, new_manager: new_manager, added_at: get_block_timestamp()
                    }
                );
            return self.chakra_managers.read(new_manager) == 1;
        }
        fn remove_manager(ref self: ContractState, old_manager: ContractAddress) -> bool {
            let caller = get_caller_address();
            assert(self.chakra_managers.read(caller) == 1, Errors::NOT_MANAGER);
            self.chakra_managers.write(old_manager, 0);
            self
                .emit(
                    ManagerRemoved {
                        operator: caller,
                        old_manager: old_manager,
                        removed_at: get_block_timestamp()
                    }
                );
            return self.chakra_managers.read(old_manager) == 0;
        }

        fn is_manager(self: @ContractState, manager: ContractAddress) -> bool {
            return self.chakra_managers.read(manager) == 1;
        }

        fn send_cross_chain_msg(
            ref self: ContractState, to_chain: felt252, to_handler: u256, payload_type :u8,payload: Array<u8>,
        ) -> felt252 {
            let from_handler = get_caller_address();
            let from_chain = get_tx_info().unbox().chain_id;
            let cross_chain_settlement_id = LegacyHash::hash(get_tx_info().unbox().transaction_hash, self.tx_count.read());
            self.created_tx.write(cross_chain_settlement_id, CreatedTx{
                tx_id:cross_chain_settlement_id,
                from_chain: from_chain,
                to_chain: to_chain,
                from_handler: from_handler,
                to_handler: to_handler
            });
            
            self
                .emit(
                    CrossChainMsg {
                        cross_chain_settlement_id: cross_chain_settlement_id,
                        from_address: get_tx_info().unbox().account_contract_address,
                        from_chain: from_chain,
                        to_chain: to_chain,
                        from_handler: from_handler,
                        to_handler: to_handler,
                        payload_type: payload_type,
                        payload: payload
                    }
                );
            self.tx_count.write(self.tx_count.read()+1);
            return cross_chain_settlement_id;
        }

        fn receive_cross_chain_msg(
            ref self: ContractState,
            cross_chain_msg_id: u256,
            from_chain: felt252,
            to_chain: felt252,
            from_handler: u256,
            to_handler: ContractAddress,
            sign_type: u8,
            signatures: Array<(felt252, felt252, bool)>,
            payload: Array<u8>,
            payload_type: u8,
        ) -> bool {
            assert(to_chain == self.chain_name.read(), 'error to_chain');

            // verify signatures
            let mut message_hash: felt252 = LegacyHash::hash(from_chain, (cross_chain_msg_id, to_chain, from_handler, to_handler));
            let payload_span = payload.span();
            let mut i = 0;
            loop {
                if i > payload_span.len()-1{
                    break;
                }
                message_hash = LegacyHash::hash(message_hash, * payload_span.at(i));
                i += 1;
            };
            self.check_chakra_signatures(message_hash, signatures);

            // call handler receive_cross_chain_msg
            let handler = IHandlerDispatcher{contract_address: to_handler};
            let success = handler.receive_cross_chain_msg(cross_chain_msg_id, from_chain, to_chain, from_handler, to_handler , payload);

            let mut status = CrossChainMsgStatus::SUCCESS;
            if success{
                status = CrossChainMsgStatus::SUCCESS;
            }else{
                status = CrossChainMsgStatus::FAILED;
            }

            self.received_tx.write(cross_chain_msg_id, ReceivedTx{
                tx_id:cross_chain_msg_id,
                from_chain: from_chain,
                from_handler: from_handler,
                to_chain: to_chain,
                to_handler: to_handler,
                tx_status: status
            });

            // emit event
            self.emit(CrossChainHandleResult{
                cross_chain_settlement_id: cross_chain_msg_id,
                from_chain: to_chain,
                from_handler: to_handler,
                to_chain: from_chain,
                to_handler: from_handler,
                cross_chain_msg_status: status,
                payload_type: payload_type
            });
            return true;
        }

        fn receive_cross_chain_callback(
            ref self: ContractState,
            cross_chain_msg_id: felt252,
            from_chain: felt252,
            to_chain: felt252,
            from_handler: ContractAddress,
            to_handler: u256,
            cross_chain_msg_status: u8,
            sign_type: u8,
            signatures: Array<(felt252, felt252, bool)>,
        ) -> bool {
            let mut message_hash_temp: felt252 = LegacyHash::hash(from_chain, (cross_chain_msg_id, to_chain, from_handler, to_handler));
            let message_hash_final:felt252 = LegacyHash::hash(message_hash_temp, cross_chain_msg_status);
            self.check_chakra_signatures(message_hash_final, signatures);
            let handler = IHandlerDispatcher{contract_address: from_handler};
            handler.receive_cross_chain_callback(cross_chain_msg_id, from_chain, to_chain, from_handler, to_handler , cross_chain_msg_status);
            self.emit(CrossChainResult {
                cross_chain_settlement_id: cross_chain_msg_id,
                from_address: get_tx_info().unbox().account_contract_address,
                from_chain: from_chain,
                from_handler: from_handler,
                to_chain: to_chain,
                to_handler: to_handler,
                cross_chain_msg_status: cross_chain_msg_status,
            });
            return true;
        }

        fn get_recevied_tx(self: @ContractState, tx_id: u256) -> ReceivedTx{
            return self.received_tx.read(tx_id);
        }

        fn get_created_tx(self: @ContractState, tx_id: felt252) -> CreatedTx{
            return self.created_tx.read(tx_id);
        }

        fn set_chain_name(ref self: ContractState, chain_name: felt252){
            self.ownable.assert_only_owner();
            self.chain_name.write(chain_name);
        }

        fn chain_name(self: @ContractState) -> felt252{
            return self.chain_name.read();
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            // This function can only be called by the owner
            self.ownable.assert_only_owner();

            // Replace the class hash upgrading the contract
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}