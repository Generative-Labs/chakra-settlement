use core::option::OptionTrait;
use core::traits::TryInto;
use core::traits::Into;
use core::box::BoxTrait;
use snforge_std::{declare, ContractClassTrait, start_prank, CheatTarget};

use starknet::ContractAddress;
use starknet::ClassHash;
use starknet::{get_tx_info, get_caller_address};
use settlement_cairo::interfaces::{IHandlerDispatcher, IHandlerDispatcherTrait, IChakraSettlementDispatcher, IChakraSettlementDispatcherTrait};
use openzeppelin::upgrades::interface::{IUpgradeableDispatcher};

#[test]
fn test(){
    let settlement_contract = declare("ChakraSettlement");
    let settlement_address = settlement_contract.deploy(@array![0x5a9bd6214db5b229bd17a4050585b21c87fc0cadf9871f89a099d27ef800a40, 1]).unwrap();
    let test_handler_contract = declare("SettlementHandlerTest");
    let test_handler_address = test_handler_contract.deploy(@array![settlement_address.into()]).unwrap();
    let settlement_dispatch = IChakraSettlementDispatcher {contract_address: settlement_address};
    let handler_dispath = IHandlerDispatcher {contract_address: test_handler_address};
    // send_cross_chain_msg
    let tx_id = handler_dispath.send_cross_chain_msg(1, 1, array![1]);
    assert(settlement_dispatch.get_created_tx(tx_id).to_chain==1, 'save to chain error');
    assert(settlement_dispatch.get_created_tx(tx_id).to_handler==1, 'save to handler error');
    assert(settlement_dispatch.get_created_tx(tx_id).from_chain==get_tx_info().unbox().chain_id, 'save from chain error');
    assert(settlement_dispatch.get_created_tx(tx_id).from_handler==test_handler_address, 'save to from handler error');
    // receive_cross_chain_msg
    settlement_dispatch.receive_cross_chain_msg(1, 1 ,1 ,1, test_handler_address, 1, array![(1,1,false)],array![1],1);
    assert(settlement_dispatch.get_recevied_tx(1).from_chain == 1, 'save from_chain error');
    assert(settlement_dispatch.get_recevied_tx(1).to_chain == 1, 'save to_chain error');
    assert(settlement_dispatch.get_recevied_tx(1).from_handler == 1, 'save from_handler error');
    assert(settlement_dispatch.get_recevied_tx(1).to_handler == test_handler_address, 'save to_handler error');
    assert(settlement_dispatch.get_recevied_tx(1).tx_status == 2, 'save tx_status error');
    // receive_cross_chain_callback
    settlement_dispatch.receive_cross_chain_callback(1, get_tx_info().unbox().chain_id, 1, test_handler_address, 1,2,1,array![(1,1,false)]);
}

#[test]
fn validator_test(){
    let settlement_contract = declare("ChakraSettlement");
    let settlement_address = settlement_contract.deploy(@array![0x5a9bd6214db5b229bd17a4050585b21c87fc0cadf9871f89a099d27ef800a40, 1]).unwrap();
    let settlement_dispatch = IChakraSettlementDispatcher {contract_address: settlement_address};
    let owner = 0x5a9bd6214db5b229bd17a4050585b21c87fc0cadf9871f89a099d27ef800a40.try_into().unwrap();
    start_prank(CheatTarget::One(settlement_address), owner);
    settlement_dispatch.add_validator(1);
    assert(settlement_dispatch.is_validator(1), 'add validator error');
    settlement_dispatch.remove_validator(1);
    assert(!settlement_dispatch.is_validator(1), 'remove validator error');
}

#[test]
fn manager_test(){
    let settlement_contract = declare("ChakraSettlement");
    let settlement_address = settlement_contract.deploy(@array![0x5a9bd6214db5b229bd17a4050585b21c87fc0cadf9871f89a099d27ef800a40, 1]).unwrap();
    let settlement_dispatch = IChakraSettlementDispatcher {contract_address: settlement_address};
    let owner = 0x5a9bd6214db5b229bd17a4050585b21c87fc0cadf9871f89a099d27ef800a40.try_into().unwrap();
    start_prank(CheatTarget::One(settlement_address), owner);
    settlement_dispatch.add_manager(1.try_into().unwrap());
    assert(settlement_dispatch.is_manager(1.try_into().unwrap()), 'add manager error');
    settlement_dispatch.remove_manager(1.try_into().unwrap());
    assert(!settlement_dispatch.is_manager(1.try_into().unwrap()), 'remove manager error');
}