// Copyright 2022-2023 ComingChat Authors. Licensed under Apache-2.0 License.
module dmens::profile {
    use std::bcs;
    use std::hash::sha3_256;
    use std::vector;

    use sui::dynamic_object_field as dof;
    use sui::ed25519::ed25519_verify;
    use sui::object::{Self, ID, UID};
    use sui::object_table::{Self, ObjectTable};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::url::{Self, Url};

    use dmens::dmens::{dmens_meta, destory_all, DmensMeta};

    // on testnet
    // const INIT_CAPTCHA_PUBLIC_KEY: vector<u8> = x"a7bcde68ec805cc414865bd07ad13a0bb519473bfe5018edc55c60a571616cad";
    // on mainnet
    const INIT_CAPTCHA_PUBLIC_KEY: vector<u8> = x"2798a48215521de12536c72a3ac317a9b128b4b98cab18545b3ffe129be0e762";
    const URL_GLOABL: vector<u8> = b"ipfs://bafkreibat54rwwfuxm377yj5vlhjhyj7cbzex2tdhktxmom6rdco54up5a";
    const URL_PROFILE: vector<u8> = b"ipfs://bafkreibat54rwwfuxm377yj5vlhjhyj7cbzex2tdhktxmom6rdco54up5a";

    const ERR_NO_PERMISSIONS: u64 = 1;
    const ERR_INVALID_CAPTCHA: u64 = 2;

    struct WrapperProfile has key, store {
        id: UID,
        profile: vector<u8>,
        owner: address,
        url: Url
    }

    struct Global has key {
        id: UID,
        creator: address,
        captcha_public_key: vector<u8>,
        profiles: ObjectTable<address, WrapperProfile>,
        url: Url
    }

    fun init(ctx: &mut TxContext) {
        transfer::share_object(
            Global {
                id: object::new(ctx),
                creator: tx_context::sender(ctx),
                captcha_public_key: INIT_CAPTCHA_PUBLIC_KEY,
                profiles: object_table::new<address, WrapperProfile>(ctx),
                url: url::new_unsafe_from_bytes(URL_GLOABL)
            }
        )
    }

    public fun has_exsits(
        global: &Global,
        user: address
    ): bool {
        object_table::contains(&global.profiles, user)
    }

    public fun global_verify(
        global: &Global,
        signature: vector<u8>,
        captcha: vector<u8>
    ) {
        assert!(
            ed25519_verify(&signature, &global.captcha_public_key, &captcha),
            ERR_INVALID_CAPTCHA
        );
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

        global_verify(global, signature, captcha);

        if (!has_exsits(global, user)) {
            let wrapper_profile = WrapperProfile {
                id: object::new(ctx),
                url: url::new_unsafe_from_bytes(URL_PROFILE),
                owner: user,
                profile
            };

            object_table::add(&mut global.profiles, user, wrapper_profile);
            dmens_meta(ctx);
        };

        let mut_profile = object_table::borrow_mut(&mut global.profiles, user);
        mut_profile.profile = profile
    }

    /// Attach an Item to a WrapperProfile.
    /// Function is generic and allows any app to attach items to WrapperProfile
    /// But the total count of items has to be lower than 255.
    public entry fun add_item<T: key + store>(
        global: &mut Global,
        item: T,
        ctx: &mut TxContext
    ) {
        let user = tx_context::sender(ctx);
        let mut_profile = object_table::borrow_mut(&mut global.profiles, user);

        dof::add(&mut mut_profile.id, object::id(&item), item);
    }

    /// Remove item from the WrapperProfile.
    public entry fun remove_item<T: key + store>(
        global: &mut Global,
        item_id: ID,
        ctx: &mut TxContext
    ) {
        let user = tx_context::sender(ctx);
        let mut_profile = object_table::borrow_mut(&mut global.profiles, user);

        transfer::public_transfer(
            dof::remove<ID, T>(&mut mut_profile.id, item_id),
            tx_context::sender(ctx)
        );
    }

    /// Destory the account
    /// Profile and dmens_meta will be delete.
    public entry fun destroy(
        global: &mut Global,
        meta: DmensMeta,
        ctx: &mut TxContext
    ) {
        let wrapper_profile = object_table::remove(
            &mut global.profiles,
            tx_context::sender(ctx)
        );

        let WrapperProfile { id, profile: _profile, url: _url, owner: _owner } = wrapper_profile;
        object::delete(id);

        destory_all(meta)
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        transfer::share_object(
            Global {
                id: object::new(ctx),
                creator: tx_context::sender(ctx),
                captcha_public_key: x"1ECFFCFE36FA28E7B21C936373EAC4F345EC5B66E2BDE7E67444ADBFAF614B09",
                profiles: object_table::new<address, WrapperProfile>(ctx),
                url: url::new_unsafe_from_bytes(URL_GLOABL)
            }
        )
    }

    #[test]
    fun test_ed25519_verify() {
        use std::hash;
        use sui::ed25519::ed25519_verify;

        let _privkey = x"1B934F07804CEEEA5D9D59BE1834345EE747BEBD939D92E68F41FAC98C9C374B";
        let pubkey = x"1ECFFCFE36FA28E7B21C936373EAC4F345EC5B66E2BDE7E67444ADBFAF614B09";

        let signature = x"7423732E9A3BDB39A685C0B9FCB0B6272A443C7E9889D1DC4AD9BA17C0FEF7BA5064D7826C4EE32CFC42EB7F2822CC7DAB7327D482EFD56A1E912BA333A8160D";
        // origin msg: 0x000000000000000000000000000000000000000000000000000000000000000b + 'test'
        let origin_msg = x"000000000000000000000000000000000000000000000000000000000000000b0474657374";
        let sign_msg = x"a1da62e532921ed2c13c1b68219bfd8943de4648897467030b727d7d7903af02";

        assert!(sign_msg == hash::sha3_256(origin_msg), 1);

        assert!(ed25519_verify(&signature, &pubkey, &sign_msg), 2)
    }
}
