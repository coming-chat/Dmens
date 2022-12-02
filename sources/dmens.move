// Copyright 2022 ComingChat Authors. Licensed under Apache-2.0 License.
// Dmens is a reduction of "Decentralized Moments",
// building a blockchain Twitter protocol on the Sui network,
// and integrating it in ComingChat in the form of a product similar
// to WeChat Moments.
module dmens::dmens {
    use std::option::{Self, Option, some, none};
    use std::string::{Self, String};
    use std::vector::length;

    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::vec_set::{Self, VecSet};
    use sui::event::emit;

    friend dmens::profile;

    /// Max text length.
    /// Refer to https://github.com/twitter/twitter-text/blob/master/config/v3.json
    const MAX_TEXT_LENGTH: u64 = 280;

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

    struct FollowEvent has copy, drop {
        account: address,
        target: address,
        to_follow: bool
    }

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

    struct Follows has key {
        id: UID,
        accounts: VecSet<address>
    }

    public(friend) fun new_follow(
        ctx: &mut TxContext,
    ) {
        transfer::transfer(
            Follows {
                id: object::new(ctx),
                accounts: vec_set::empty<address>()
            },
            tx_context::sender(ctx)
        )
    }

    /// For ACTION_POST
    fun post_internal(
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

        transfer::transfer(dmens, tx_context::sender(ctx));
    }

    /// For ACTION_RETWEET
    fun retweet_internal(
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

        transfer::transfer(dmens, tx_context::sender(ctx));
    }

    /// For ACTION_QUOTE_TWEET
    fun quote_tweet_internal(
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

        transfer::transfer(dmens, tx_context::sender(ctx));
    }

    /// For ACTION_REPLY
    fun reply_internal(
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

        transfer::transfer(dmens, tx_context::sender(ctx));
    }

    /// For ACTION_ATTACH
    fun attach_internal(
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

        transfer::transfer(dmens, tx_context::sender(ctx));
    }

    /// For ACTION_LIKE
    fun like_internal(
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

        transfer::transfer(dmens, tx_context::sender(ctx));
    }

    /// Mint (post) a Dmens object without referencing another object.
    public entry fun post(
        app_identifier: u8,
        action: u8,
        text: vector<u8>,
        ctx: &mut TxContext,
    ) {
        if (action == ACTION_POST) {
            post_internal(app_identifier, text, ctx);
        } else {
            abort ERR_UNEXPECTED_ACTION
        }
    }

    /// Mint (post) a Dmens object and reference another
    /// object (i.e., to simulate retweet, reply, like, attach).
    public entry fun post_with_ref(
        app_identifier: u8,
        action: u8,
        text: vector<u8>,
        ref_identifier: address,
        ctx: &mut TxContext,
    ) {
        if (action == ACTION_RETWEET) {
            retweet_internal(app_identifier, some(ref_identifier), ctx)
        } else if (action == ACTION_QUOTE_TWEET) {
            quote_tweet_internal(app_identifier, text, some(ref_identifier), ctx)
        } else if (action == ACTION_REPLY) {
            reply_internal(app_identifier, text, some(ref_identifier), ctx)
        } else if (action == ACTION_ATTACH) {
            attach_internal(app_identifier, text, some(ref_identifier), ctx)
        } else if (action == ACTION_LIKE) {
            like_internal(app_identifier, some(ref_identifier), ctx)
        } else {
            abort ERR_UNEXPECTED_ACTION
        }
    }

    /// Burn a Dmens object.
    public entry fun burn(dmens: Dmens) {
        let Dmens { id, app_id: _, poster: _, text: _, ref_id: _, action: _ } = dmens;
        object::delete(id);
    }

    public entry fun follow(
        follows: &mut Follows,
        account: address,
        to_follow: bool,
        ctx: &mut TxContext,
    ) {
        if (to_follow) {
            vec_set::insert(&mut follows.accounts, account);
        } else {
            vec_set::remove(&mut follows.accounts, &account);
        };

        emit(
            FollowEvent {
                account,
                target: tx_context::sender(ctx),
                to_follow
            }
        )
    }
}
