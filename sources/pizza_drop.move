module pizza_drop::airdrop {
    use std::signer; //Provides access to the signer object representing the transaction sender Used for authentication and authorization
    use aptos_framework::account; //Account management utilities. Functions for creating accounts, checking account existence, etc.
    use aptos_std::table::{Self, Table}; //Table data structure for storing key-value pairs. Useful for mapping data (like user balances, NFT collections, etc.)
    use aptos_framework::event; //Event system for emitting on-chain events. Used for logging and off-chain indexing
    use aptos_framework::timestamp; //Access to blockchain timestamp functionality. Useful for time-based logic
    use aptos_framework::coin::{Self, Coin}; //Core coin/token functionality. Functions for minting, burning, transferring coins
    use aptos_framework::aptos_coin::AptosCoin; //Specific import for Aptos native token (APT). The base currency of the Aptos network

    #[test_only]
    use std::debug;

    /// Error codes
    const E_NOT_OWNER: u64 = 1;
    const E_NOT_REGISTERED: u64 = 2;
    const E_ALREADY_CLAIMED: u64 = 3;
    const E_INSUFFICIENT_FUND: u64 = 4;

    #[event]
    struct PizzaClaimed has drop, store {
        user: address,
        amount: u64,
    }

    #[event]
    struct PizzaLoverRegistered has drop, store {
        user: address,
    }

    struct ModuleData has key {
        signer_cap: account::SignerCapability,
    }

    struct State has key {
        users_claimed_amount: Table<address, u64>,
        claimed_users: Table<address, bool>,
        owner: address,
        balance: u64,
    }

    /// Initialize the module
    fun init_module(deployer: &signer) {
        let seed = b"pizza_drop";
        let (resource_signer, resource_signer_cap) = account::create_resource_account(deployer, seed);
        
        move_to(deployer, ModuleData {
            signer_cap: resource_signer_cap,
        });

        let state = State {
            users_claimed_amount: table::new(),
            claimed_users: table::new(),
            owner: signer::address_of(deployer),
            balance: 0,
        };
        move_to(&resource_signer, state);

        // Register the resource account to receive APT
        coin::register<AptosCoin>(&resource_signer);
    }

    public entry fun register_pizza_lover(owner: &signer, user: address) acquires ModuleData, State {
        let state = borrow_global_mut<State>(get_resource_address());
        assert!(signer::address_of(owner) == state.owner, E_NOT_OWNER);
        get_random_slice(user);
        event::emit(PizzaLoverRegistered {
            user: user,
        });
    }

    public entry fun fund_pizza_drop(owner: &signer, amount: u64) acquires ModuleData, State {
        let state = borrow_global_mut<State>(get_resource_address());
        assert!(signer::address_of(owner) == state.owner, E_NOT_OWNER);

        let resource_addr = get_resource_address();
        
        // Transfer APT from owner to the resource account
        coin::transfer<AptosCoin>(owner, resource_addr, amount);
        state.balance = state.balance + amount;
    }

    public entry fun claim_pizza_slice(user: &signer) acquires ModuleData, State {
        let user_addr = signer::address_of(user);
        let state = borrow_global_mut<State>(get_resource_address());
        
        assert!(table::contains(&state.users_claimed_amount, user_addr), E_NOT_REGISTERED);
        assert!(!table::contains(&state.claimed_users, user_addr), E_ALREADY_CLAIMED);
        
        let amount = *table::borrow(&state.users_claimed_amount, user_addr);
        
        // Check if contract has sufficient balance
        assert!(state.balance >= amount, E_INSUFFICIENT_FUND);
        
        // Register user to receive APT if not already registered
        if (!coin::is_account_registered<AptosCoin>(user_addr)) {
            coin::register<AptosCoin>(user);
        };
        
        transfer_from_contract(user_addr, amount);
        
        // Update balance
        state.balance = state.balance - amount;
        
        table::add(&mut state.claimed_users, user_addr, true);
        
        event::emit(PizzaClaimed {
            user: user_addr,
            amount: amount,
        });
    }

    fun transfer_from_contract(to: address, amount: u64) acquires ModuleData {
        let module_data = borrow_global<ModuleData>(@pizza_drop);
        let resource_signer = account::create_signer_with_capability(&module_data.signer_cap);
        
        // Transfer APT from resource account to user
        coin::transfer<AptosCoin>(&resource_signer, to, amount);
    }
    
    #[randomness]
    entry fun get_random_slice(user_addr: address) acquires ModuleData, State {
        let state = borrow_global_mut<State>(get_resource_address());
        let time = timestamp::now_microseconds();
        let random_val = time % 401;
        let random_amount = 100 + random_val;  // 100-500 APT (in Octas: 10^8 smallest unit)
        table::add(&mut state.users_claimed_amount, user_addr, random_amount);
    }

    #[view]
    fun get_resource_address(): address acquires ModuleData {
        let module_data = borrow_global<ModuleData>(@pizza_drop);
        let resource_signer = account::create_signer_with_capability(&module_data.signer_cap);
        signer::address_of(&resource_signer)
    }

    #[view]
    public fun is_registered(user: address): bool acquires ModuleData, State {
        let state = borrow_global<State>(get_resource_address());
        table::contains(&state.users_claimed_amount, user)
    }

    #[view]
    public fun has_claimed_slice(user: address): bool acquires ModuleData, State {
        let state = borrow_global<State>(get_resource_address());
        if (!table::contains(&state.claimed_users, user)) {
            return false
        };
        table::contains(&state.claimed_users, user)
    }

    #[view]
    public fun get_pizza_pool_balance(): u64 acquires ModuleData, State {
        let state = borrow_global<State>(get_resource_address());
        state.balance
    }

    #[view]
    public fun get_claimed_amount(user: address): u64 acquires ModuleData, State {
        let state = borrow_global<State>(get_resource_address());
        if (!table::contains(&state.users_claimed_amount, user)) {
            return 0
        };
        let amount = table::borrow(&state.users_claimed_amount, user);
        *amount
    }

    // Get the actual APT balance of the resource account
    #[view]
    public fun get_actual_apt_balance(): u64 acquires ModuleData {
        let resource_addr = get_resource_address();
        coin::balance<AptosCoin>(resource_addr)
    }

    // WORKING TEST WITH APTOS COIN
    #[test(deployer = @pizza_drop, user = @0x123, framework = @0x1)]
    fun test_pizza_drop_with_apt(deployer: &signer, user: &signer, framework: &signer) acquires State, ModuleData {
        use aptos_framework::account;
        use aptos_framework::timestamp;
        use aptos_framework::aptos_coin;

        // Initialize timestamp and APT for testing
        timestamp::set_time_has_started_for_testing(framework);
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(framework);

        // Create accounts
        account::create_account_for_test(@pizza_drop);
        account::create_account_for_test(signer::address_of(user));

        debug::print(&b"=== PIZZA DROP WITH APT TEST ===");

        // Initialize the pizza drop module
        init_module(deployer);
        debug::print(&b"Pizza drop module initialized");

        // Mint APT to deployer for funding
        let funding_amount = 100000; // 0.001 APT in Octas
        let deployer_coins = coin::mint<AptosCoin>(funding_amount, &mint_cap);
        coin::register<AptosCoin>(deployer);
        coin::deposit<AptosCoin>(@pizza_drop, deployer_coins);

        let deployer_balance = coin::balance<AptosCoin>(@pizza_drop);
        debug::print(&b"Deployer APT balance: ");
        debug::print(&deployer_balance);

        // Fund the pizza drop contract
        let contract_funding = 10000; // 0.0001 APT
        fund_pizza_drop(deployer, contract_funding);
        
        let contract_balance = get_actual_apt_balance();
        debug::print(&b"Contract APT balance: ");
        debug::print(&contract_balance);
        assert!(contract_balance == contract_funding, 1);

        // Register a user for the airdrop
        let user_addr = signer::address_of(user);
        register_pizza_lover(deployer, user_addr);
        
        assert!(is_registered(user_addr), 2);
        debug::print(&b"User registered successfully");

        // Check the assigned amount
        let assigned_amount = get_claimed_amount(user_addr);
        debug::print(&b"User assigned amount: ");
        debug::print(&assigned_amount);
        assert!(assigned_amount >= 100 && assigned_amount <= 500, 3);

        // Verify user hasn't claimed yet
        assert!(!has_claimed_slice(user_addr), 4);

        // User claims their pizza slice
        claim_pizza_slice(user);
        
        // Verify claim was successful
        assert!(has_claimed_slice(user_addr), 5);
        debug::print(&b"User claimed their slice");

        // Check final balances
        let user_apt_balance = coin::balance<AptosCoin>(user_addr);
        assert!(user_apt_balance == assigned_amount, 6);
        debug::print(&b"User APT balance: ");
        debug::print(&user_apt_balance);

        let final_contract_balance = get_actual_apt_balance();
        let expected_contract_balance = contract_funding - assigned_amount;
        assert!(final_contract_balance == expected_contract_balance, 7);
        debug::print(&b"Final contract balance: ");
        debug::print(&final_contract_balance);

        // Verify internal balance tracking matches actual balance
        let tracked_balance = get_pizza_pool_balance();
        assert!(tracked_balance == expected_contract_balance, 8);
        debug::print(&b"Tracked balance: ");
        debug::print(&tracked_balance);

        // Clean up
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);

        debug::print(&b"=== PIZZA DROP TEST PASSED! ===");
    }

    // Test multiple users
    #[test(deployer = @pizza_drop, user1 = @0x123, user2 = @0x456, framework = @0x1)]
    fun test_multiple_users_apt(
        deployer: &signer, 
        user1: &signer, 
        user2: &signer, 
        framework: &signer
    ) acquires State, ModuleData {
        use aptos_framework::account;
        use aptos_framework::timestamp;
        use aptos_framework::aptos_coin;

        // Setup
        timestamp::set_time_has_started_for_testing(framework);
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(framework);

        account::create_account_for_test(@pizza_drop);
        account::create_account_for_test(signer::address_of(user1));
        account::create_account_for_test(signer::address_of(user2));

        debug::print(&b"=== MULTIPLE USERS TEST ===");

        // Initialize and fund
        init_module(deployer);
        
        let funding_amount = 100000;
        let deployer_coins = coin::mint<AptosCoin>(funding_amount, &mint_cap);
        coin::register<AptosCoin>(deployer);
        coin::deposit<AptosCoin>(@pizza_drop, deployer_coins);

        fund_pizza_drop(deployer, 50000);

        // Register both users
        let user1_addr = signer::address_of(user1);
        let user2_addr = signer::address_of(user2);

        register_pizza_lover(deployer, user1_addr);
        register_pizza_lover(deployer, user2_addr);

        assert!(is_registered(user1_addr), 1);
        assert!(is_registered(user2_addr), 2);

        let amount1 = get_claimed_amount(user1_addr);
        let amount2 = get_claimed_amount(user2_addr);

        debug::print(&b"User1 amount: ");
        debug::print(&amount1);
        debug::print(&b"User2 amount: ");
        debug::print(&amount2);

        // Both users claim
        claim_pizza_slice(user1);
        claim_pizza_slice(user2);

        // Verify both claimed
        assert!(has_claimed_slice(user1_addr), 3);
        assert!(has_claimed_slice(user2_addr), 4);

        // Verify balances
        let user1_balance = coin::balance<AptosCoin>(user1_addr);
        let user2_balance = coin::balance<AptosCoin>(user2_addr);

        assert!(user1_balance == amount1, 5);
        assert!(user2_balance == amount2, 6);

        let final_contract_balance = get_actual_apt_balance();
        let expected_balance = 50000 - amount1 - amount2;
        assert!(final_contract_balance == expected_balance, 7);

        debug::print(&b"User1 final balance: ");
        debug::print(&user1_balance);
        debug::print(&b"User2 final balance: ");
        debug::print(&user2_balance);
        debug::print(&b"Contract final balance: ");
        debug::print(&final_contract_balance);

        // Clean up
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);

        debug::print(&b"=== MULTIPLE USERS TEST PASSED! ===");
    }

    // Test error cases
    #[test(deployer = @pizza_drop, user = @0x123, framework = @0x1)]
    #[expected_failure(abort_code = E_ALREADY_CLAIMED)]
    fun test_double_claim_fails(deployer: &signer, user: &signer, framework: &signer) acquires State, ModuleData {
        use aptos_framework::account;
        use aptos_framework::timestamp;
        use aptos_framework::aptos_coin;

        // Setup
        timestamp::set_time_has_started_for_testing(framework);
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(framework);

        account::create_account_for_test(@pizza_drop);
        account::create_account_for_test(signer::address_of(user));

        init_module(deployer);
        
        let funding_amount = 100000;
        let deployer_coins = coin::mint<AptosCoin>(funding_amount, &mint_cap);
        coin::register<AptosCoin>(deployer);
        coin::deposit<AptosCoin>(@pizza_drop, deployer_coins);

        fund_pizza_drop(deployer, 10000);

        let user_addr = signer::address_of(user);
        register_pizza_lover(deployer, user_addr);
        
        // First claim should succeed
        claim_pizza_slice(user);
        
        // Second claim should fail
        claim_pizza_slice(user); // This should abort with E_ALREADY_CLAIMED

        // Clean up (won't reach here)
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
}
