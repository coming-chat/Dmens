// Copyright 2022 ComingChat Authors. Licensed under Apache-2.0 License.
#[test_only]
module dmens::dmens_test {
    use sui::test_scenario::{Self, Scenario};

    use dmens::dmens::{Self, DmensMeta};
    use dmens::profile::Global;

    const CREATOR: address = @0xA;
    const USER: address = @0xB;

    fun init_(scenario: &mut Scenario) {
        dmens::profile::init_for_testing(test_scenario::ctx(scenario));
    }

    fun register_(scenario: &mut Scenario) {
        let global = test_scenario::take_shared<Global>(scenario);

        dmens::profile::register(
            &mut global,
            b"test",
            x"2B1CE19FA75C46E07A7C66D489C56308A431CB4A3A0624B9D20777CD180CD9013CC2F4486FE9F82195D477F8A3CD4E0ED15DBD85A272147038358ACED02AC809",
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
}
