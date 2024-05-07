import asyncio

from starknet_py.hash.selector import get_selector_from_name
from starknet_py.net.account.account import Account
from starknet_py.net.client_models import Call
from starknet_py.net.full_node_client import FullNodeClient
from starknet_py.net.models import StarknetChainId
from starknet_py.net.signer.stark_curve_signer import KeyPair

contract_address = 0x6d2f4cf10eec1ebfb54f5cb6e9ab48e3ea442a2812576decd73814779afa57e

async def add_white_list(addresses: [int], prv_key, address_int):
    client = FullNodeClient('https://starknet-mainnet.g.alchemy.com/v2/JnR9OZ0EoYZTyhz91Kko2UkLLZ1jH7Eu')
    key_pair = KeyPair.from_private_key(key=prv_key)
    account = Account(client=client, address=address_int, key_pair=key_pair, chain=StarknetChainId.MAINNET)
    calls = []
    for address in addresses:
        add_white_list_call = Call(to_addr=contract_address, selector=get_selector_from_name('add_white_list'), calldata=[address])
        calls.append(add_white_list_call)
    resp = await account.execute_v1(calls=calls, max_fee=int(1e15))
    print('tx_hash', hex(resp.transaction_hash))