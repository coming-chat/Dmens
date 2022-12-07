// Copyright 2022 ComingChat Authors. Licensed under Apache-2.0 License.
// Dmens is a reduction of "Decentralized Moments",
// building a blockchain Twitter protocol on the Sui network,
// and integrating it in ComingChat in the form of a product similar
// to WeChat Moments.
module dmens::dmens {
    use std::option::{Self, Option, some, none};
    use std::string::{Self, String};
    use std::vector::{Self, length};

    use sui::object::{Self, UID};
    use sui::table::{Self, Table};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    friend dmens::profile;

    /// Max text length.
    const MAX_TEXT_LENGTH: u64 = 10000;

    /// Action Types
    const ACTION_POST: u8 = 0;
    const ACTION_RETWEET: u8 = 1;
    const ACTION_QUOTE_TWEET: u8 = 2;
    const ACTION_REPLY: u8 = 3;
    const ACTION_ATTACH: u8 = 4;
    const ACTION_LIKE: u8 = 5;

    /// APP IDs for filter
    const APP_ID_FOR_COMINGCHAT_APP: u8 = 0;
    const APP_ID_FOR_COMINGCHAT_WEB: u8 = 1;

    /// Text size overflow.
    const ERR_TEXT_OVERFLOW: u64 = 0;
    /// Require reference Dmens id
    const ERR_REQUIRE_REF_ID: u64 = 1;
    /// Unsupport action
    const ERR_UNEXPECTED_ACTION: u64 = 2;

    /// Dmens NFT (i.e., a post, retweet, like, reply message etc).
    struct Dmens has key, store {
        id: UID,
        // The ID of the dmens app.
        app_id: u8,
        // The poster of the dmens
        poster: address,
        // Post's text.
        text: Option<String>,
        // Set if referencing an another object (i.e., due to a Like, Retweet, Reply etc).
        // We allow referencing any object type, not ony Dmens NFTs.
        ref_id: Option<address>,
        // Which action create the Dmens.
        action: u8,
    }

    /// Meta config for user
    struct DmensMeta has key {
        id: UID,
        next_index: u64,
        follows: Table<address, address>,
        dmens_table: Table<u64, Dmens>
    }

    /// Called when the first profile::register
    public(friend) fun dmens_meta(
        ctx: &mut TxContext,
    ) {
        transfer::transfer(
            DmensMeta {
                id: object::new(ctx),
                next_index: 0,
                follows: table::new<address, address>(ctx),
                dmens_table: table::new<u64, Dmens>(ctx)
            },
            tx_context::sender(ctx)
        )
    }

    /// Called when the profile::destory
    public(friend) fun destory_all(
        meta: DmensMeta,
    ) {
        let next_index = meta.next_index;
        batch_burn(&mut meta, 0, next_index);

        let DmensMeta { id, next_index: _, dmens_table, follows } = meta;

        // Dmens no drop ability, so use destroy_empty
        table::destroy_empty(dmens_table);

        table::drop(follows);
        object::delete(id);
    }

    /// For ACTION_POST
    fun post_internal(
        meta: &mut DmensMeta,
        app_id: u8,
        text: vector<u8>,
        ctx: &mut TxContext,
    ) {
        assert!(length(&text) <= MAX_TEXT_LENGTH, ERR_TEXT_OVERFLOW);

        let dmens = Dmens {
            id: object::new(ctx),
            app_id,
            poster: tx_context::sender(ctx),
            text: some(string::utf8(text)),
            ref_id: none(),
            action: ACTION_POST
        };

        table::add(&mut meta.dmens_table, meta.next_index, dmens);
        meta.next_index = meta.next_index + 1
    }

    /// For ACTION_RETWEET
    fun retweet_internal(
        meta: &mut DmensMeta,
        app_id: u8,
        ref_id: Option<address>,
        ctx: &mut TxContext,
    ) {
        assert!(option::is_some(&ref_id), ERR_REQUIRE_REF_ID);

        let dmens = Dmens {
            id: object::new(ctx),
            app_id,
            poster: tx_context::sender(ctx),
            text: none(),
            ref_id,
            action: ACTION_RETWEET,
        };

        table::add(&mut meta.dmens_table, meta.next_index, dmens);
        meta.next_index = meta.next_index + 1
    }

    /// For ACTION_QUOTE_TWEET
    fun quote_tweet_internal(
        meta: &mut DmensMeta,
        app_id: u8,
        text: vector<u8>,
        ref_id: Option<address>,
        ctx: &mut TxContext,
    ) {
        assert!(length(&text) <= MAX_TEXT_LENGTH, ERR_TEXT_OVERFLOW);
        assert!(option::is_some(&ref_id), ERR_REQUIRE_REF_ID);

        let dmens = Dmens {
            id: object::new(ctx),
            app_id,
            poster: tx_context::sender(ctx),
            text: some(string::utf8(text)),
            ref_id,
            action: ACTION_QUOTE_TWEET
        };

        table::add(&mut meta.dmens_table, meta.next_index, dmens);
        meta.next_index = meta.next_index + 1
    }

    /// For ACTION_REPLY
    fun reply_internal(
        meta: &mut DmensMeta,
        app_id: u8,
        text: vector<u8>,
        ref_id: Option<address>,
        ctx: &mut TxContext,
    ) {
        assert!(length(&text) <= MAX_TEXT_LENGTH, ERR_TEXT_OVERFLOW);
        assert!(option::is_some(&ref_id), ERR_REQUIRE_REF_ID);

        let dmens = Dmens {
            id: object::new(ctx),
            app_id,
            poster: tx_context::sender(ctx),
            text: some(string::utf8(text)),
            ref_id,
            action: ACTION_REPLY
        };

        table::add(&mut meta.dmens_table, meta.next_index, dmens);
        meta.next_index = meta.next_index + 1
    }

    /// For ACTION_ATTACH
    fun attach_internal(
        meta: &mut DmensMeta,
        app_id: u8,
        text: vector<u8>,
        ref_id: Option<address>,
        ctx: &mut TxContext,
    ) {
        assert!(length(&text) <= MAX_TEXT_LENGTH, ERR_TEXT_OVERFLOW);
        assert!(option::is_some(&ref_id), ERR_REQUIRE_REF_ID);

        let dmens = Dmens {
            id: object::new(ctx),
            app_id,
            poster: tx_context::sender(ctx),
            text: some(string::utf8(text)),
            ref_id,
            action: ACTION_ATTACH
        };

        table::add(&mut meta.dmens_table, meta.next_index, dmens);
        meta.next_index = meta.next_index + 1
    }

    /// For ACTION_LIKE
    fun like_internal(
        meta: &mut DmensMeta,
        app_id: u8,
        ref_id: Option<address>,
        ctx: &mut TxContext,
    ) {
        assert!(option::is_some(&ref_id), ERR_REQUIRE_REF_ID);

        let dmens = Dmens {
            id: object::new(ctx),
            app_id,
            poster: tx_context::sender(ctx),
            text: none(),
            ref_id,
            action: ACTION_LIKE,
        };

        table::add(&mut meta.dmens_table, meta.next_index, dmens);
        meta.next_index = meta.next_index + 1
    }

    /// Mint (post) a Dmens object without referencing another object.
    /// Call by user
    public entry fun post(
        meta: &mut DmensMeta,
        app_identifier: u8,
        action: u8,
        text: vector<u8>,
        ctx: &mut TxContext,
    ) {
        if (action == ACTION_POST) {
            post_internal(meta, app_identifier, text, ctx);
        } else {
            abort ERR_UNEXPECTED_ACTION
        }
    }

    /// Mint (post) a Dmens object and reference another.
    /// object (i.e., to simulate retweet, reply, like, attach).
    /// Call by user
    public entry fun post_with_ref(
        meta: &mut DmensMeta,
        app_identifier: u8,
        action: u8,
        text: vector<u8>,
        ref_identifier: address,
        ctx: &mut TxContext,
    ) {
        if (action == ACTION_RETWEET) {
            retweet_internal(meta, app_identifier, some(ref_identifier), ctx)
        } else if (action == ACTION_QUOTE_TWEET) {
            quote_tweet_internal(meta, app_identifier, text, some(ref_identifier), ctx)
        } else if (action == ACTION_REPLY) {
            reply_internal(meta, app_identifier, text, some(ref_identifier), ctx)
        } else if (action == ACTION_ATTACH) {
            attach_internal(meta, app_identifier, text, some(ref_identifier), ctx)
        } else if (action == ACTION_LIKE) {
            like_internal(meta, app_identifier, some(ref_identifier), ctx)
        } else {
            abort ERR_UNEXPECTED_ACTION
        }
    }

    /// Burn a Dmens object.
    /// Call by user
    public entry fun burn(dmens: Dmens) {
        let Dmens { id, app_id: _, poster: _, text: _, ref_id: _, action: _ } = dmens;
        object::delete(id);
    }

    /// Follow accounts.
    /// Call by user
    public entry fun follow(
        meta: &mut DmensMeta,
        accounts: vector<address>,
    ) {
        let (i, len) = (0, vector::length(&accounts));
        while (i < len) {
            let account = vector::pop_back(&mut accounts);
            table::add(&mut meta.follows, account, account);
            i = i + 1
        };
    }

    /// Unfollow accounts.
    /// Call by user
    public entry fun unfollow(
        meta: &mut DmensMeta,
        accounts: vector<address>,
    ) {
        let (i, len) = (0, vector::length(&accounts));
        while (i < len) {
            let account = vector::pop_back(&mut accounts);

            if (table::contains(&meta.follows, account)) {
                table::remove(&mut meta.follows, account);
            };

            i = i + 1
        };
    }

    /// Batch burn [start, end) dmens objects.
    /// Call by user
    public entry fun batch_burn(
        meta: &mut DmensMeta,
        start: u64,
        end: u64
    ) {
        let real_end = if (meta.next_index < end) {
            meta.next_index
        } else {
            end
        };

        while (start < real_end) {
            if (table::contains(&meta.dmens_table, start)) {
                // Remove a dynamic field actually requires deleting the underlying object
                // https://github.com/MystenLabs/sui/pull/6593
                burn(table::remove(&mut meta.dmens_table, start))
            };

            start = start + 1
        }
    }

    /// Burn the dmens object by index.
    /// Call by user
    public entry fun burn_with_index(
        meta: &mut DmensMeta,
        index: u64,
    ) {
        let dmens = table::remove(&mut meta.dmens_table, index);
        let Dmens { id, app_id: _, poster: _, text: _, ref_id: _, action: _ } = dmens;
        object::delete(id);
    }

    /// Take the dmens object from table and transfer it to receiver.
    /// Call by user
    public entry fun take(
        meta: &mut DmensMeta,
        index: u64,
        receiver: address,
    ) {
        transfer::transfer(
            table::remove(&mut meta.dmens_table, index),
            receiver
        )
    }

    /// Place the dmens object to table.
    /// Call by user
    public entry fun place(
        meta: &mut DmensMeta,
        dmens: Dmens,
    ) {
        table::add(&mut meta.dmens_table, meta.next_index, dmens);
        meta.next_index = meta.next_index + 1
    }
}
