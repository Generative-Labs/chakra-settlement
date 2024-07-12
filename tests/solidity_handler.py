from web3 import Web3
import json

from dotenv import load_dotenv
import os

#  .env
load_dotenv()

web3 = Web3(Web3.HTTPProvider(os.getenv("CHAKRA_RPC_URL")))

# HandlerContract
contract_address = '0xFd9c324c77023B802478c6a37Cd9B2de12b23289'


account_address = os.getenv("CHAKRA_ACCOUNT")
private_key = os.getenv("CHAKRA_ACCOUNT_PRIVATE_KEY")


if not web3.is_connected():
    print("Not Connect")
    exit()

# ABI JSON
with open('abi/solidity.handler.json', 'r') as abi_file:
    contract_abi = json.load(abi_file)

contract = web3.eth.contract(address=contract_address, abi=contract_abi)

nonce = web3.eth.get_transaction_count(account_address)
print("Nonce: ", nonce)

btc_txid = 12345678910
btc_address = 'tb1p0d8vtv7c0skytnj9rpps495r4726pasfhj4hxxq4ph5gxjhptpws9q698f'
receive_address = '0x940D583861e57ab1c7F83D5a9450323CAe38402b'
amount = 1000

preTran = contract.functions.deposit_request(btc_txid, btc_address, receive_address, amount)


transaction = preTran.build_transaction({
    'chainId': 8545,
    'gas': 2000000,
    'gasPrice': web3.to_wei('50', 'gwei'),
    'nonce': nonce,
})

signed_txn = web3.eth.account.sign_transaction(transaction, private_key)
txn_hash = web3.eth.send_raw_transaction(signed_txn.rawTransaction)

print(f"Result: {txn_hash.hex()}")

txn_receipt = web3.eth.wait_for_transaction_receipt(txn_hash)
print(f"BlockNumber: {txn_receipt.blockNumber}")

