// Copyright 2022-2023 ComingChat Authors. Licensed under Apache-2.0 License.
#[test_only]
module dmens::dmens_test {
    use std::option::some;
    use std::vector;

    use sui::test_scenario::{Self, Scenario};

    use dmens::dmens::{Self, DmensMeta, Dmens, Like, Repost};
    use dmens::profile::Global;

    const CREATOR: address = @0xA;
    const USER: address = @0xB;
    const SOME_POST: address = @0xC;

    /// Max text length.
    const MAX_TEXT_LENGTH: u64 = 10000;

    /// Action Types
    const ACTION_POST: u8 = 0;
    const ACTION_REPOST: u8 = 1;
    const ACTION_QUOTE_POST: u8 = 2;
    const ACTION_REPLY: u8 = 3;
    const ACTION_LIKE: u8 = 4;

    /// APP IDs for filter
    const APP_ID_FOR_COMINGCHAT_TEST: u8 = 3;

    fun init_(scenario: &mut Scenario) {
        dmens::profile::init_for_testing(test_scenario::ctx(scenario));
    }

    fun register_(scenario: &mut Scenario) {
        let global = test_scenario::take_shared<Global>(scenario);

        dmens::profile::register(
            &mut global,
            b"test",
            x"7423732E9A3BDB39A685C0B9FCB0B6272A443C7E9889D1DC4AD9BA17C0FEF7BA5064D7826C4EE32CFC42EB7F2822CC7DAB7327D482EFD56A1E912BA333A8160D",
            test_scenario::ctx(scenario)
        );

        assert!(dmens::profile::has_exsits(&global, USER), 1);

        test_scenario::return_shared(global);
    }

    fun destroy_(scenario: &mut Scenario) {
        let global = test_scenario::take_shared<Global>(scenario);
        let dmens_meta = test_scenario::take_from_sender<DmensMeta>(scenario);

        dmens::profile::destroy(
            &mut global,
            dmens_meta,
            test_scenario::ctx(scenario)
        );

        assert!(!dmens::profile::has_exsits(&global, USER), 2);

        test_scenario::return_shared(global);
    }

    fun follow_(scenario: &mut Scenario) {
        let dmens_meta = test_scenario::take_from_sender<DmensMeta>(scenario);

        let accounts = vector::empty<address>();
        vector::push_back(&mut accounts, CREATOR);
        dmens::follow(
            &mut dmens_meta,
            accounts
        );
        assert!(dmens::meta_has_following(&dmens_meta, CREATOR), 3);

        test_scenario::return_to_sender(scenario, dmens_meta)
    }

    fun unfollow_(scenario: &mut Scenario) {
        let dmens_meta = test_scenario::take_from_sender<DmensMeta>(scenario);

        let accounts = vector::empty<address>();
        vector::push_back(&mut accounts, CREATOR);
        dmens::unfollow(
            &mut dmens_meta,
            accounts,
        );
        assert!(dmens::meta_follows(&dmens_meta) == 0, 4);

        test_scenario::return_to_sender(scenario, dmens_meta)
    }

    fun post_(
        app_identifier: u8,
        action: u8,
        text: vector<u8>,
        scenario: &mut Scenario
    ) {
        let dmens_meta = test_scenario::take_from_sender<DmensMeta>(scenario);

        let dmens_index = dmens::meta_index(&dmens_meta);
        dmens::post(
            &mut dmens_meta,
            app_identifier,
            action,
            text,
            test_scenario::ctx(scenario)
        );
        assert!(dmens::meta_index(&dmens_meta) == dmens_index + 1, 5);

        test_scenario::return_to_sender(scenario, dmens_meta)
    }

    fun like_(
        app_identifier: u8,
        action: u8,
        text: vector<u8>,
        ref_identifier: address,
        take_index: u64,
        scenario: &mut Scenario
    ) {
        let dmens_meta = test_scenario::take_from_sender<DmensMeta>(scenario);

        let dmens_index = dmens::meta_index(&dmens_meta);
        dmens::post_with_ref(
            &mut dmens_meta,
            app_identifier,
            action,
            text,
            ref_identifier,
            test_scenario::ctx(scenario)
        );
        assert!(dmens::meta_index(&dmens_meta) == dmens_index + 1, 6);
        test_scenario::return_to_sender(scenario, dmens_meta);

        test_scenario::next_tx(scenario, USER);
        {
            let dmens_meta = test_scenario::take_from_sender<DmensMeta>(scenario);

            let like_object = test_scenario::take_from_address<Like>(scenario, SOME_POST);
            assert!(dmens::parse_like(&like_object) == USER, 1);
            test_scenario::return_to_address(SOME_POST, like_object);

            let indexes = vector::empty<u64>();
            vector::push_back(&mut indexes, take_index);

            dmens::batch_take(
                &mut dmens_meta,
                indexes,
                USER
            );

            test_scenario::return_to_sender(scenario, dmens_meta)
        };

        test_scenario::next_tx(scenario, USER);
        {
            let dmens_like = test_scenario::take_from_sender<Dmens>(scenario);

            let (_app, poster, _text, ref_id, action) = dmens::parse_dmens(&dmens_like);
            assert!(poster == USER, 2);
            assert!(ref_id == some(SOME_POST), 3);
            assert!(action == ACTION_LIKE, 4);

            let burns = vector::empty<Dmens>();
            vector::push_back(&mut burns, dmens_like);

            dmens::batch_burn_objects(burns)
        };

        test_scenario::next_tx(scenario, USER);
        {
            let dmens_meta = test_scenario::take_from_sender<DmensMeta>(scenario);

            assert!(dmens::meta_dmens_count(&dmens_meta) == 0, 5);

            test_scenario::return_to_sender(scenario, dmens_meta)
        };
    }

    fun repost_or_quote_post_(
        app_identifier: u8,
        action: u8,
        text: vector<u8>,
        ref_identifier: address,
        take_index: u64,
        dmens_count: u64,
        scenario: &mut Scenario
    ) {
        let dmens_meta = test_scenario::take_from_sender<DmensMeta>(scenario);

        let dmens_index = dmens::meta_index(&dmens_meta);
        dmens::post_with_ref(
            &mut dmens_meta,
            app_identifier,
            action,
            text,
            ref_identifier,
            test_scenario::ctx(scenario)
        );
        assert!(dmens::meta_index(&dmens_meta) == dmens_index + 1, 7);
        test_scenario::return_to_sender(scenario, dmens_meta);

        test_scenario::next_tx(scenario, USER);
        {
            let dmens_meta = test_scenario::take_from_sender<DmensMeta>(scenario);

            let repost_object = test_scenario::take_from_address<Repost>(scenario, SOME_POST);
            assert!(dmens::parse_repost(&repost_object) == USER, 1);
            test_scenario::return_to_address(SOME_POST, repost_object);

            let indexes = vector::empty<u64>();
            vector::push_back(&mut indexes, take_index);

            dmens::batch_take(
                &mut dmens_meta,
                indexes,
                USER
            );

            test_scenario::return_to_sender(scenario, dmens_meta)
        };

        test_scenario::next_tx(scenario, USER);
        {
            let dmens_meta = test_scenario::take_from_sender<DmensMeta>(scenario);

            let dmens_repost = test_scenario::take_from_sender<Dmens>(scenario);

            let (_app, poster, _text, ref_id, action_type) = dmens::parse_dmens(&dmens_repost);
            assert!(poster == USER, 2);
            assert!(ref_id == some(SOME_POST), 3);
            assert!(action_type == action, 4);

            let dmens_vec = vector::empty<Dmens>();
            vector::push_back(&mut dmens_vec, dmens_repost);

            dmens::batch_place(&mut dmens_meta, dmens_vec);

            test_scenario::return_to_sender(scenario, dmens_meta)
        };

        test_scenario::next_tx(scenario, USER);
        {
            let dmens_meta = test_scenario::take_from_sender<DmensMeta>(scenario);

            assert!(dmens::meta_dmens_count(&dmens_meta) == dmens_count, 5);

            test_scenario::return_to_sender(scenario, dmens_meta)
        };
    }

    fun reply_(
        app_identifier: u8,
        action: u8,
        text: vector<u8>,
        ref_identifier: address,
        scenario: &mut Scenario
    ) {
        let dmens_meta = test_scenario::take_from_sender<DmensMeta>(scenario);

        let dmens_index = dmens::meta_index(&dmens_meta);
        dmens::post_with_ref(
            &mut dmens_meta,
            app_identifier,
            action,
            text,
            ref_identifier,
            test_scenario::ctx(scenario)
        );
        assert!(dmens::meta_index(&dmens_meta) == dmens_index + 1, 8);

        test_scenario::return_to_sender(scenario, dmens_meta)
    }

    fun batch_(count: u64, scenario: &mut Scenario) {
        let dmens_meta = test_scenario::take_from_sender<DmensMeta>(scenario);

        let i = 0u64;
        while (i < count) {
            dmens::post(
                &mut dmens_meta,
                APP_ID_FOR_COMINGCHAT_TEST,
                ACTION_POST,
                b"post",
                test_scenario::ctx(scenario)
            );
            i = i + 1
        };

        assert!(dmens::meta_index(&dmens_meta) == count, 9);

        test_scenario::return_to_sender(scenario, dmens_meta)
    }

    #[test]
    fun test_register() {
        let begin = test_scenario::begin(CREATOR);
        let scenario = &mut begin;

        init_(scenario);

        test_scenario::next_tx(scenario, USER);
        register_(scenario);

        test_scenario::next_tx(scenario, USER);
        {
            let dmens_meta = test_scenario::take_from_sender<DmensMeta>(scenario);

            assert!(dmens::meta_follows(&dmens_meta) == 0, 1);
            assert!(dmens::meta_dmens_count(&dmens_meta) == 0, 2);
            assert!(dmens::meta_index(&dmens_meta) == 0, 3);

            test_scenario::return_to_sender(scenario, dmens_meta);
        };

        test_scenario::end(begin);
    }

    #[test]
    fun test_destory() {
        let begin = test_scenario::begin(CREATOR);
        let scenario = &mut begin;

        init_(scenario);

        test_scenario::next_tx(scenario, USER);
        register_(scenario);

        test_scenario::next_tx(scenario, USER);
        destroy_(scenario);

        test_scenario::end(begin);
    }

    #[test]
    fun test_follow() {
        let begin = test_scenario::begin(CREATOR);
        let scenario = &mut begin;

        init_(scenario);
        test_scenario::next_tx(scenario, USER);
        register_(scenario);

        test_scenario::next_tx(scenario, USER);
        follow_(scenario);

        test_scenario::end(begin);
    }

    #[test]
    #[expected_failure]
    fun test_follow_one_account_twice_should_fail() {
        let begin = test_scenario::begin(CREATOR);
        let scenario = &mut begin;

        init_(scenario);
        test_scenario::next_tx(scenario, USER);
        register_(scenario);

        test_scenario::next_tx(scenario, USER);
        follow_(scenario);

        test_scenario::next_tx(scenario, USER);
        follow_(scenario);

        test_scenario::end(begin);
    }

    #[test]
    fun test_unfollow() {
        let begin = test_scenario::begin(CREATOR);
        let scenario = &mut begin;

        init_(scenario);
        test_scenario::next_tx(scenario, USER);
        register_(scenario);

        test_scenario::next_tx(scenario, USER);
        follow_(scenario);

        test_scenario::next_tx(scenario, USER);
        unfollow_(scenario);

        test_scenario::end(begin);
    }

    #[test]
    fun test_unfollow_without_followings_should_ok() {
        let begin = test_scenario::begin(CREATOR);
        let scenario = &mut begin;

        init_(scenario);
        test_scenario::next_tx(scenario, USER);
        register_(scenario);

        test_scenario::next_tx(scenario, USER);
        unfollow_(scenario);

        test_scenario::end(begin);
    }

    #[test]
    fun test_post_action() {
        let begin = test_scenario::begin(CREATOR);
        let scenario = &mut begin;

        init_(scenario);
        test_scenario::next_tx(scenario, USER);
        register_(scenario);

        test_scenario::next_tx(scenario, USER);
        post_(
            APP_ID_FOR_COMINGCHAT_TEST,
            ACTION_POST,
            b"test_post",
            scenario
        );

        test_scenario::end(begin);
    }

    #[test]
    #[expected_failure(abort_code = dmens::dmens::ERR_INVALID_ACTION)]
    fun test_post_invalid_action_emtpy_text() {
        let begin = test_scenario::begin(CREATOR);
        let scenario = &mut begin;

        init_(scenario);
        test_scenario::next_tx(scenario, USER);
        register_(scenario);

        test_scenario::next_tx(scenario, USER);
        post_(
            APP_ID_FOR_COMINGCHAT_TEST,
            ACTION_POST,
            b"",
            scenario
        );

        test_scenario::end(begin);
    }

    #[test]
    #[expected_failure(abort_code = dmens::dmens::ERR_TEXT_OVERFLOW)]
    fun test_post_invalid_action_text_too_long() {
        let begin = test_scenario::begin(CREATOR);
        let scenario = &mut begin;

        init_(scenario);
        test_scenario::next_tx(scenario, USER);
        register_(scenario);

        test_scenario::next_tx(scenario, USER);
        let (i, text) = (0, vector::empty<u8>());
        while (i < MAX_TEXT_LENGTH) {
            vector::push_back(&mut text, 0u8);
            i = i + 1;
        };
        vector::push_back(&mut text, 0u8);


        post_(
            APP_ID_FOR_COMINGCHAT_TEST,
            ACTION_POST,
            text,
            scenario
        );

        test_scenario::end(begin);
    }

    #[test]
    fun test_like_action() {
        let begin = test_scenario::begin(CREATOR);
        let scenario = &mut begin;

        init_(scenario);
        test_scenario::next_tx(scenario, USER);
        register_(scenario);

        test_scenario::next_tx(scenario, USER);
        like_(
            APP_ID_FOR_COMINGCHAT_TEST,
            ACTION_LIKE,
            b"",
            SOME_POST,
            0,
            scenario
        );

        test_scenario::end(begin);
    }

    #[test]
    #[expected_failure(abort_code = dmens::dmens::ERR_INVALID_ACTION)]
    fun test_like_invalid_action() {
        let begin = test_scenario::begin(CREATOR);
        let scenario = &mut begin;

        init_(scenario);
        test_scenario::next_tx(scenario, USER);
        register_(scenario);

        test_scenario::next_tx(scenario, USER);
        like_(
            APP_ID_FOR_COMINGCHAT_TEST,
            ACTION_LIKE,
            b"test_like",
            SOME_POST,
            0,
            scenario
        );

        test_scenario::end(begin);
    }

    #[test]
    fun test_like_action_twice_should_ok() {
        let begin = test_scenario::begin(CREATOR);
        let scenario = &mut begin;

        init_(scenario);
        test_scenario::next_tx(scenario, USER);
        register_(scenario);

        test_scenario::next_tx(scenario, USER);
        like_(
            APP_ID_FOR_COMINGCHAT_TEST,
            ACTION_LIKE,
            b"",
            SOME_POST,
            0,
            scenario
        );

        test_scenario::next_tx(scenario, USER);
        like_(
            APP_ID_FOR_COMINGCHAT_TEST,
            ACTION_LIKE,
            b"",
            SOME_POST,
            1,
            scenario
        );

        test_scenario::end(begin);
    }

    #[test]
    fun test_repost_action() {
        let begin = test_scenario::begin(CREATOR);
        let scenario = &mut begin;

        init_(scenario);
        test_scenario::next_tx(scenario, USER);
        register_(scenario);

        test_scenario::next_tx(scenario, USER);
        repost_or_quote_post_(
            APP_ID_FOR_COMINGCHAT_TEST,
            ACTION_REPOST,
            b"",
            SOME_POST,
            0,
            1,
            scenario
        );

        test_scenario::end(begin);
    }

    #[test]
    fun test_repost_action_twice_should_ok() {
        let begin = test_scenario::begin(CREATOR);
        let scenario = &mut begin;

        init_(scenario);
        test_scenario::next_tx(scenario, USER);
        register_(scenario);

        test_scenario::next_tx(scenario, USER);
        repost_or_quote_post_(
            APP_ID_FOR_COMINGCHAT_TEST,
            ACTION_REPOST,
            b"",
            SOME_POST,
            0,
            1,
            scenario
        );

        test_scenario::next_tx(scenario, USER);
        repost_or_quote_post_(
            APP_ID_FOR_COMINGCHAT_TEST,
            ACTION_REPOST,
            b"",
            SOME_POST,
            1,
            2,
            scenario
        );

        test_scenario::end(begin);
    }

    #[test]
    fun test_quote_post_action() {
        let begin = test_scenario::begin(CREATOR);
        let scenario = &mut begin;

        init_(scenario);
        test_scenario::next_tx(scenario, USER);
        register_(scenario);

        test_scenario::next_tx(scenario, USER);
        repost_or_quote_post_(
            APP_ID_FOR_COMINGCHAT_TEST,
            ACTION_QUOTE_POST,
            b"test_quote_post",
            SOME_POST,
            0,
            1,
            scenario
        );

        test_scenario::end(begin);
    }

    #[test]
    fun test_quote_post_action_twice_should_ok() {
        let begin = test_scenario::begin(CREATOR);
        let scenario = &mut begin;

        init_(scenario);
        test_scenario::next_tx(scenario, USER);
        register_(scenario);

        test_scenario::next_tx(scenario, USER);
        repost_or_quote_post_(
            APP_ID_FOR_COMINGCHAT_TEST,
            ACTION_QUOTE_POST,
            b"test_quote_post",
            SOME_POST,
            0,
            1,
            scenario
        );

        test_scenario::next_tx(scenario, USER);
        repost_or_quote_post_(
            APP_ID_FOR_COMINGCHAT_TEST,
            ACTION_QUOTE_POST,
            b"test_quote_post",
            SOME_POST,
            1,
            2,
            scenario
        );

        test_scenario::end(begin);
    }

    #[test]
    fun test_reply_action() {
        let begin = test_scenario::begin(CREATOR);
        let scenario = &mut begin;

        init_(scenario);
        test_scenario::next_tx(scenario, USER);
        register_(scenario);

        test_scenario::next_tx(scenario, USER);
        reply_(
            APP_ID_FOR_COMINGCHAT_TEST,
            ACTION_REPLY,
            b"test_reply",
            SOME_POST,
            scenario
        );

        test_scenario::end(begin);
    }

    #[test]
    #[expected_failure(abort_code = dmens::dmens::ERR_UNEXPECTED_ACTION)]
    fun test_unexpected_action() {
        let begin = test_scenario::begin(CREATOR);
        let scenario = &mut begin;

        init_(scenario);
        test_scenario::next_tx(scenario, USER);
        register_(scenario);

        test_scenario::next_tx(scenario, USER);
        post_(
            APP_ID_FOR_COMINGCHAT_TEST,
            ACTION_REPLY,
            b"test_reply",
            scenario
        );

        test_scenario::end(begin);
    }

    #[test]
    fun test_batch_burn_indexes() {
        let begin = test_scenario::begin(CREATOR);
        let scenario = &mut begin;

        init_(scenario);
        test_scenario::next_tx(scenario, USER);
        register_(scenario);

        test_scenario::next_tx(scenario, USER);
        batch_(100, scenario);

        test_scenario::next_tx(scenario, USER);
        {
            let dmens_meta = test_scenario::take_from_sender<DmensMeta>(scenario);
            let burns = vector::empty<u64>();
            vector::push_back(&mut burns, 0);
            vector::push_back(&mut burns, 99);
            vector::push_back(&mut burns, 0);

            assert!(dmens::meta_dmens_exist(&dmens_meta, 0), 1);
            assert!(dmens::meta_dmens_exist(&dmens_meta, 99), 2);

            dmens::batch_burn_indexes(&mut dmens_meta, burns);

            assert!(dmens::meta_dmens_count(&dmens_meta) == 98, 3);
            assert!(!dmens::meta_dmens_exist(&dmens_meta, 0), 4);
            assert!(!dmens::meta_dmens_exist(&dmens_meta, 99), 5);

            test_scenario::return_to_sender(scenario, dmens_meta)
        };

        test_scenario::end(begin);
    }

    #[test]
    fun test_batch_burn_range() {
        let begin = test_scenario::begin(CREATOR);
        let scenario = &mut begin;

        init_(scenario);
        test_scenario::next_tx(scenario, USER);
        register_(scenario);

        test_scenario::next_tx(scenario, USER);
        batch_(100, scenario);

        test_scenario::next_tx(scenario, USER);
        {
            let dmens_meta = test_scenario::take_from_sender<DmensMeta>(scenario);

            dmens::batch_burn_range(&mut dmens_meta, 0, 10);
            assert!(dmens::meta_dmens_count(&dmens_meta) == 90, 1);

            dmens::batch_burn_range(&mut dmens_meta, 10, 20);
            assert!(dmens::meta_dmens_count(&dmens_meta) == 80, 2);

            dmens::batch_burn_range(&mut dmens_meta, 10, 25);
            assert!(dmens::meta_dmens_count(&dmens_meta) == 75, 3);

            dmens::batch_burn_range(&mut dmens_meta, 25, 25);
            assert!(dmens::meta_dmens_count(&dmens_meta) == 75, 4);

            dmens::batch_burn_range(&mut dmens_meta, 25, 26);
            assert!(dmens::meta_dmens_count(&dmens_meta) == 74, 5);

            dmens::batch_burn_range(&mut dmens_meta, 90, 101);
            assert!(dmens::meta_dmens_count(&dmens_meta) == 64, 6);

            dmens::batch_burn_range(&mut dmens_meta, 90, 201);
            assert!(dmens::meta_dmens_count(&dmens_meta) == 64, 7);

            dmens::batch_burn_range(&mut dmens_meta, 0, 201);
            assert!(dmens::meta_dmens_count(&dmens_meta) == 0, 8);

            test_scenario::return_to_sender(scenario, dmens_meta)
        };

        test_scenario::end(begin);
    }
}
