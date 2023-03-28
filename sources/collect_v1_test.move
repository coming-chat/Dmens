// Copyright 2022-2023 ComingChat Authors. Licensed under Apache-2.0 License.
#[test_only]
module dmens::collect_v1_test {
    use std::debug::print;
    use std::string::{String, utf8};

    use sui::coin::{Coin, mint_for_testing};
    use sui::sui::SUI;
    use sui::test_scenario::{Self, Scenario, ctx, take_shared, return_shared, take_from_sender, return_to_sender, has_most_recent_for_sender};

    use dmens::collect_v1::{Self, calculate_captcha, NFT};
    use dmens::profile::Global;

    const CREATOR: address = @0xA;
    const USER: address = @0xB;

    fun init_(scenario: &mut Scenario) {
        dmens::profile::init_for_testing(test_scenario::ctx(scenario));
    }

    fun get_test_data(scenario: &mut Scenario)
    : (vector<address>, vector<u64>, vector<Coin<SUI>>, vector<u8>)
    {
        let recipients = vector<address>[USER];
        let amounts = vector<u64>[1000000000];
        let coins = vector<Coin<SUI>>[
            mint_for_testing<SUI>(1000000000, ctx(scenario))
        ];

        let captcha = calculate_captcha(
            &recipients,
            &amounts,
            &coins
        );

        return (recipients, amounts, coins, captcha)
    }

    fun collect_(scenario: &mut Scenario) {
        let (
            recipients,
            amounts,
            coins,
            _captcha
        ) = get_test_data(scenario);

        let signature = x"EE0C971A5AD6B25962850EB859AC68BD7B7F30AF4491B7898C48D0D01B456C3679B817AC79D43FA9B66122BA8A892EC9AC1AD8834659CFFA8B9F3C89973EA108";

        let attributes_key = vector<String>[
            utf8(b"key1"),
            utf8(b"key2")
        ];
        let attributes_value = vector<String>[
            utf8(b"value1"),
            utf8(b"value2")
        ];

        let global = take_shared<Global>(scenario);

        collect_v1::collect(
            &global,
            signature,
            recipients,
            amounts,
            coins,
            attributes_key,
            attributes_value,
            ctx(scenario)
        );

        return_shared(global);
    }

    fun burn_(scenario: &mut Scenario) {
        let nft = take_from_sender<NFT>(scenario);
        collect_v1::burn(nft)
    }

    #[test]
    fun test_collect() {
        let begin = test_scenario::begin(CREATOR);
        let scenario = &mut begin;

        init_(scenario);

        test_scenario::next_tx(scenario, USER);
        collect_(scenario);

        test_scenario::next_tx(scenario, USER);
        {
            let nft = take_from_sender<NFT>(scenario);

            print(&nft);

            return_to_sender(scenario, nft);
        };

        test_scenario::end(begin);
    }

    #[test]
    fun test_burn() {
        let begin = test_scenario::begin(CREATOR);
        let scenario = &mut begin;

        init_(scenario);

        test_scenario::next_tx(scenario, USER);
        collect_(scenario);

        test_scenario::next_tx(scenario, USER);
        {
            assert!(has_most_recent_for_sender<NFT>(scenario), 1);
        };

        burn_(scenario);

        test_scenario::next_tx(scenario, USER);
        {
            assert!(!has_most_recent_for_sender<NFT>(scenario), 2);
        };
        test_scenario::end(begin);
    }
}