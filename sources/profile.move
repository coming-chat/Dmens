// Copyright 2022 ComingChat Authors. Licensed under Apache-2.0 License.
module dmens::profile {
    use std::vector;

    use sui::object::{Self, UID};
    use sui::table::{Self, Table};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::vec_set::{Self, VecSet};

    const ERR_NO_PERMISSIONS: u64 = 1;

    // TODO: update profile with admin signature verification
    struct Global has key {
        id: UID,
        creator: address,
        admins: VecSet<address>,
        profiles: Table<address, vector<u8>>
    }

    fun init(ctx: &mut TxContext) {
        transfer::share_object(
            Global {
                id: object::new(ctx),
                creator: tx_context::sender(ctx),
                admins: vec_set::empty<address>(),
                profiles: table::new<address, vector<u8>>(ctx),
            }
        )
    }

    public entry fun add_admin(
        global: &mut Global,
        new_admin: address,
        ctx: &mut TxContext
    ) {
        assert!(global.creator == tx_context::sender(ctx), ERR_NO_PERMISSIONS);
        vec_set::insert(&mut global.admins, new_admin)
    }

    public entry fun remove_admin(
        global: &mut Global,
        old_admin: address,
        ctx: &mut TxContext
    ) {
        assert!(global.creator == tx_context::sender(ctx), ERR_NO_PERMISSIONS);
        vec_set::remove(&mut global.admins, &old_admin)
    }

    public entry fun update_profile(
        global: &mut Global,
        user: address,
        user_profile: vector<u8>,
        ctx: &mut TxContext
    ) {
        let operator = tx_context::sender(ctx);
        assert!(
            global.creator == operator
                || vec_set::contains(&global.admins, &operator),
            ERR_NO_PERMISSIONS
        );

        if (!table::contains(&global.profiles, user)) {
            table::add(&mut global.profiles, user, vector::empty<u8>())
        };

        let mut_profile = table::borrow_mut(&mut global.profiles, user);
        *mut_profile = user_profile
    }
}
