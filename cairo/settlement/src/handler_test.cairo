#[starknet::contract]
mod SettlementHandlerTest{
    use settlement_cairo::interfaces::IChakraSettlementDispatcherTrait;
    use starknet::ContractAddress;
    use settlement_cairo::interfaces::IHandler;
    use settlement_cairo::interfaces::IChakraSettlementDispatcher;
    #[constructor]
    fn constructor(ref self: ContractState, settlement_address: ContractAddress) {
        self.settlement_address.write(settlement_address);
    }
    
    #[storage]
    struct Storage {
        settlement_address: ContractAddress
    }

    #[abi(embed_v0)]
    impl SettlementHandlerTestImpl of IHandler<ContractState> {
        fn receive_cross_chain_msg(ref self: ContractState, cross_chain_msg_id: u256, from_chain: felt252, to_chain: felt252,
        from_handler: u256, to_handler: ContractAddress, payload: Array<u8>) -> bool{
            return true;
        }
        fn receive_cross_chain_callback(ref self: ContractState, cross_chain_msg_id: felt252, from_chain: felt252, to_chain: felt252,
        from_handler: ContractAddress, to_handler: u256, cross_chain_msg_status: u8) -> bool{
            return true;
        }

        fn send_cross_chain_msg(ref self: ContractState, to_chain: felt252, to_handler: u256, payload: Array<u8>)-> felt252{
            let settlement = IChakraSettlementDispatcher {contract_address: self.settlement_address.read()};
            return settlement.send_cross_chain_msg(to_chain, to_handler, 1, payload);
        }
    }
}