// Copyright 2022 ComingChat Authors. Licensed under Apache-2.0 License.
module dmens::profile {
    use std::vector;
    use std::bcs;
    use std::hash::sha3_256;

    use sui::object::{Self, UID};
    use sui::ed25519::ed25519_verify;
    use sui::table::{Self, Table};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    use dmens::dmens::{dmens_meta, destory_all, DmensMeta};

    // TODO: replace real public key
    const INIT_CAPTCHA_PUBLIC_KEY: vector<u8> = x"";

    const ERR_NO_PERMISSIONS: u64 = 1;
    const ERR_INVALID_CAPTCHA: u64 = 2;

    struct Global has key {
        id: UID,
        creator: address,
        captcha_public_key: vector<u8>,
        profiles: Table<address, vector<u8>>
    }

    fun init(ctx: &mut TxContext) {
        transfer::share_object(
            Global {
                id: object::new(ctx),
                creator: tx_context::sender(ctx),
                captcha_public_key: INIT_CAPTCHA_PUBLIC_KEY,
                profiles: table::new<address, vector<u8>>(ctx),
            }
        )
    }

    /// Update the captcha public key.
    /// Call by deployer.
    public entry fun update_captcha_key(
        global: &mut Global,
        new_pubkey: vector<u8>,
        ctx: &mut TxContext
    ) {
        assert!(global.creator == tx_context::sender(ctx), ERR_NO_PERMISSIONS);
        global.captcha_public_key = new_pubkey
    }

    /// Register the account with profile and admin signature.
    /// If it is called for the first time, dmens_meta will be created,
    /// Otherwise only profile will be updated.
    /// Call by user
    public entry fun register(
        global: &mut Global,
        profile: vector<u8>,
        signature: vector<u8>,
        ctx: &mut TxContext
    ) {
        let user = tx_context::sender(ctx);

        let info: vector<u8> = vector::empty<u8>();
        vector::append<u8>(&mut info, bcs::to_bytes(&user));
        vector::append<u8>(&mut info, bcs::to_bytes(&profile));
        let captcha: vector<u8> = sha3_256(info);

        assert!(
            ed25519_verify(&signature, &global.captcha_public_key, &captcha),
            ERR_INVALID_CAPTCHA
        );

        if (!table::contains(&global.profiles, user)) {
            table::add(&mut global.profiles, user, vector::empty<u8>());
            dmens_meta(ctx);
        };

        let mut_profile = table::borrow_mut(&mut global.profiles, user);
        *mut_profile = profile
    }

    /// Destory the account
    /// Profile and dmens_meta will be delete.
    public entry fun destory(
        global: &mut Global,
        meta: DmensMeta,
        ctx: &mut TxContext
    ) {
        let _profile = table::remove(
            &mut global.profiles,
            tx_context::sender(ctx)
        );

        destory_all(meta)
    }

    #[test]
    fun test_ed25519_verify() {
        use sui::ed25519::ed25519_verify;

        let _privkey = x"1B934F07804CEEEA5D9D59BE1834345EE747BEBD939D92E68F41FAC98C9C374B";
        let pubkey = x"1ECFFCFE36FA28E7B21C936373EAC4F345EC5B66E2BDE7E67444ADBFAF614B09";

        let signature = x"B6A1424ACCB14F988E2A82E9B91E17575EF20878838054495D973F3370F739D7CA4E55F4A9FD85D2D7D8F259D543A3736E80F8601D89DA9CEB10FD8CE0560F01";
        let msg = b"test";

        assert!(ed25519_verify(&signature, &pubkey, &msg), 1)
    }
}
