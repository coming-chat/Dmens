// Copyright 2022-2023 ComingChat Authors. Licensed under Apache-2.0 License.
module dmens::collect_v1 {
    use std::bcs;
    use std::hash::sha3_256;
    use std::string::{String, utf8};
    use std::vector::{Self, length};

    use sui::coin::{Coin, value, destroy_zero};
    use sui::object::{Self, UID};
    use sui::pay;
    use sui::sui::SUI;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::url::{Url, new_unsafe_from_bytes};

    use dmens::profile::{Global, global_verify};

    // TODO: replace
    const NAME: vector<u8> = b"Dmens Collect";
    const DESCRIPTION: vector<u8> = b"Dmens Collect";
    const URL: vector<u8> = b"";

    const ERR_MISMATCH: u64 = 1;
    const ERR_EMPTY: u64 = 2;
    const ERR_NOT_ENOUGH: u64 = 3;

    struct NFT has store, key {
        id: UID,
        name: String,
        description: String,
        url: Url,
        attributes_key: vector<String>,
        attributes_value: vector<String>
    }

    public fun total_amount(amounts: vector<u64>): u64 {
        let (i, total, len) = (0u64, 0u64, length(&amounts));
        while (i < len) {
            total = total + vector::pop_back(&mut amounts);
            i = i + 1;
        };
        return total
    }

    public fun calculate_captcha(
        recipients: &vector<address>,
        amounts: &vector<u64>,
        coins: &vector<Coin<SUI>>,
    ): vector<u8> {
        let info: vector<u8> = vector::empty<u8>();
        vector::append<u8>(&mut info, bcs::to_bytes(recipients));
        vector::append<u8>(&mut info, bcs::to_bytes(amounts));
        vector::append<u8>(&mut info, bcs::to_bytes(coins));

        return sha3_256(info)
    }

    fun merge_coins(coins: vector<Coin<SUI>>): Coin<SUI> {
        let merged_coin = vector::pop_back(&mut coins);

        pay::join_vec(&mut merged_coin, coins);

        return merged_coin
    }

    fun settlement(
        recipients: vector<address>,
        amounts: vector<u64>,
        coins: vector<Coin<SUI>>,
        ctx: &mut TxContext
    ) {
        let (i, len) = (0u64, length(&recipients));
        assert!(len == length(&amounts), ERR_MISMATCH);
        assert!(length(&coins) > 0, ERR_EMPTY);

        let merged_coin = merge_coins(coins);
        let total = total_amount(amounts);
        assert!(value(&merged_coin) >= total, ERR_NOT_ENOUGH);

        while (i < len) {
            i = i + 1;
        };

        // transfer remain to sender
        if (value(&merged_coin) > 0) {
            transfer::public_transfer(
                merged_coin,
                tx_context::sender(ctx)
            )
        } else {
            destroy_zero(merged_coin)
        };
    }

    fun mint(
        attributes_key: vector<String>,
        attributes_value: vector<String>,
        ctx: &mut TxContext
    ) {
        transfer::transfer(
            NFT {
                id: object::new(ctx),
                name: utf8(NAME),
                description: utf8(DESCRIPTION),
                url: new_unsafe_from_bytes(URL),
                attributes_key,
                attributes_value
            },
            tx_context::sender(ctx)
        )
    }

    public entry fun burn(nft: NFT) {
        let NFT {
            id,
            name: _,
            description: _,
            url: _,
            attributes_key: _,
            attributes_value: _
        } = nft;

        object::delete(id)
    }

    public entry fun collect(
        global: &Global,
        signature: vector<u8>,
        recipients: vector<address>,
        amounts: vector<u64>,
        coins: vector<Coin<SUI>>,
        attributes_key: vector<String>,
        attributes_value: vector<String>,
        ctx: &mut TxContext
    ) {
        let captcha = calculate_captcha(&recipients, &amounts, &coins);
        global_verify(global, signature, captcha);

        settlement(recipients, amounts, coins, ctx);

        mint(attributes_key, attributes_value, ctx);
    }
}

