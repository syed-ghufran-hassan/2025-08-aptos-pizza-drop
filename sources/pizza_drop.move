module pizza_drop::airdrop {
    use std::signer; //Provides access to the signer object representing the transaction sender Used for authentication and authorization
    use aptos_framework::account; //Account management utilities. Functions for creating accounts, checking account existence, etc.
    use aptos_std::table::{Self, Table}; //Table data structure for storing key-value pairs. Useful for mapping data (like user balances, NFT collections, etc.)
    use aptos_framework::event; //Event system for emitting on-chain events. Used for logging and off-chain indexing
    use aptos_framework::timestamp; //Access to blockchain timestamp functionality. Useful for time-based logic
    use aptos_framework::coin::{Self, Coin}; //Core coin/token functionality. Functions for minting, burning, transferring coins
    use aptos_framework::aptos_coin::AptosCoin; //Specific import for Aptos native token (APT). The base currency of the Aptos network

    #[test_only]
    use std::debug; //The debug module offers functions for printing debug information during transaction execution so it needs to be used in testnet and devnet only as it consumes lot of gas.

    /// Error codes
    const E_NOT_OWNER: u64 = 1;  // Caller doesn't have ownership rights
    const E_NOT_REGISTERED: u64 = 2; // Account isn't registered in the system  
    const E_ALREADY_CLAIMED: u64 = 3; // Reward/asset already claimed by user
    const E_INSUFFICIENT_FUND: u64 = 4; // Not enough tokens/balance for operation

    #[event] //The attribute that marks this struct as an on-chain event
    struct PizzaClaimed has drop, store { //The name of the event (describes what happened) with the required abilities of events i.e. drop Allows the event to be discarded and store Allows the event to be stored in global storage
        user: address, //who performed the action
        amount: u64, //How much pizza was claimed
    }

    #[event]
    struct PizzaLoverRegistered has drop, store { // This event is emitted when a new user registers as a pizza lover in your system.
        user: address, // user address
    }

//This struct is typically stored under the module's account (usually the account that deployed the contract) and provides the module with special privileges: 

// Module Administration: Allows the module to perform privileged operations

// Resource Management: Create resources on behalf of the module account

// Fee Collection: Withdraw funds from the module account

Upgrade Capability: Manage module upgrades
    struct ModuleData has key { //This means the struct is a resource that can be stored under an account in global storage.
        signer_cap: account::SignerCapability, //A SignerCapability is a powerful object that allows generating a signer for the account it controls. It's like having a "master key" to an account
    }

    struct State has key { //this struct is stored as a resource in global storage under a specific account.
        users_claimed_amount: Table<address, u64>, //User address → Amount they claimed. Tracks how much each user has claimed. 0x123 → 500 (user at 0x123 claimed 500 units)
        claimed_users: Table<address, bool>, //User address → Whether they've claimed (true/false). Quick lookup to check if a user has claimed anything. 
        owner: address, //Admin/owner address with special privileges
        balance: u64, //Tracks the total balance/tokens in the contract
    }

    /// Initialize the module
    fun init_module(deployer: &signer) { // iT is called automatically when the module is deployed. deployer is the account that deployed the contract
        let seed = b"pizza_drop"; //Creates a resource account controlled by the module. seed ensures deterministic address generation
        let (resource_signer, resource_signer_cap) = account::create_resource_account(deployer, seed); // resource_signer can sign transactions for this account. resource_signer_cap is the capability to generate signers later
        
        move_to(deployer, ModuleData { //Stores the SignerCapability under the deployer's account. This allows the module to generate signers for the resource account later
            signer_cap: resource_signer_cap,
        });

        let state = State { //Creates the initial State struct with empty tables. Sets the deployer as the owner. Stores the state under the resource account (not the deployer's account)
            users_claimed_amount: table::new(), //Creates a new empty Table<address, u64>. Maps user addresses → amount they've claimed. 0x123 → 500 (user 0x123 claimed 500 tokens)
            claimed_users: table::new(), //Creates a new empty Table<address, bool>. Quick lookup to check if a user has claimed anything
            owner: signer::address_of(deployer), //Stores the deployer's address as the contract owner. Administrative privileges for: Withdrawing funds, Changing parameters, Upgrading contract, Emergency functions
            balance: 0, //Initializes the contract's balance to zero. Tracks total tokens/funds held by the contract.  Will be incremented when users deposit funds
        };
        move_to(&resource_signer, state); // A built-in function that stores a resource under an account. &resource_signer: The account where the resource will be stored (your resource account). The State struct containing all your contract data


        // Register the resource account to receive APT
        coin::register<AptosCoin>(&resource_signer); //coin::register: A function from the Aptos framework. <AptosCoin>: Specifies the coin type (APT token). The account being registered.
    }

    public entry fun register_pizza_lover(owner: &signer, user: address) acquires ModuleData, State { //This function allows the transaction signer (owner) to register a given user address as a pizza lover. To do this, it will need to read from and write to two important pieces of on-chain storage (ModuleData and State).
        let state = borrow_global_mut<State>(get_resource_address()); //It fetches a mutable reference to a State resource stored at a specific address calculated by get_resource_address().
        assert!(signer::address_of(owner) == state.owner, E_NOT_OWNER); //It ensures the caller (owner) is authorized by verifying their address matches the owner field stored in the State resource, aborting with an error (E_NOT_OWNER) if not.
        get_random_slice(user); //likely calls a function that performs an action for the user, such as minting them a "random slice" of pizza as a reward or token for registering.
        event::emit(PizzaLoverRegistered { //emits an on-chain event to log that the registration was successful, broadcasting the user's address for external applications to detect.
            user: user,
        });
    }

    public entry fun fund_pizza_drop(owner: &signer, amount: u64) acquires ModuleData, State { declares a public, entry function named fund_pizza_drop that takes the transaction signer and an amount of coins, and it will access the ModuleData and State global resources
        let state = borrow_global_mut<State>(get_resource_address()); //  fetches a mutable reference to the State resource stored at the module's resource account address, allowing the function to read and update its data.

        assert!(signer::address_of(owner) == state.owner, E_NOT_OWNER); //checks that the account calling this function is the authorized owner of the contract, aborting the transaction with an E_NOT_OWNER error if they are not.
        let resource_addr = get_resource_address(); //calculates and stores the address of the module's resource account, which is where the funds will be sent.
        
        // Transfer APT from owner to the resource account
        coin::transfer<AptosCoin>(owner, resource_addr, amount); //This transfers the specified amount of AptosCoin from the caller's account (owner) to the module's resource account (resource_addr).
        state.balance = state.balance + amount; //This updates the balance field in the State resource to reflect the new deposit, adding the transferred amount to the current balance.
    }

    public entry fun claim_pizza_slice(user: &signer) acquires ModuleData, State { //This declares a public function that a user can call to claim their pizza slice reward, which requires access to the ModuleData and State resources.
        let user_addr = signer::address_of(user);  // This gets the blockchain address of the user who is calling the function.
        let state = borrow_global_mut<State>(get_resource_address()); // This fetches a mutable reference to the State resource stored at the module's resource account address.
        
        assert!(table::contains(&state.users_claimed_amount, user_addr), E_NOT_REGISTERED); // This checks that the user's address exists in a lookup table (users_claimed_amount), ensuring they are registered and have an allocated amount to claim, or it fails with an E_NOT_REGISTERED error.
        assert!(!table::contains(&state.claimed_users, user_addr), E_ALREADY_CLAIMED); // This checks that the user's address is NOT in a separate lookup table (claimed_users), ensuring they haven't already claimed their reward, or it fails with an E_ALREADY_CLAIMED error.
        
        let amount = *table::borrow(&state.users_claimed_amount, user_addr); // This retrieves the specific reward amount the user is eligible to claim from the users_claimed_amount table.
        
        // Check if contract has sufficient balance
        assert!(state.balance >= amount, E_INSUFFICIENT_FUND); // This verifies that the smart contract's treasury (its balance) has enough funds to pay the user's reward, or it fails with an E_INSUFFICIENT_FUND error.
        
        // Register user to receive APT if not already registered
        if (!coin::is_account_registered<AptosCoin>(user_addr)) { // This checks if the user's account is set up to receive the AptosCoin currency.

            coin::register<AptosCoin>(user); // If the user's account is not set up (from the previous line), this line prepares their account to receive AptosCoin.
        };
        
        transfer_from_contract(user_addr, amount); //This calls a helper function (not shown here) that handles the logic of transferring the specified amount of coins from the contract's treasury to the user's address.
        
        // Update balance
        state.balance = state.balance - amount; // This updates the contract's treasury balance by subtracting the amount that was just sent to the user.
        
        table::add(&mut state.claimed_users, user_addr, true); // This adds the user's address to the claimed_users table and marks it as true, preventing them from claiming the reward again in the future.
        
        event::emit(PizzaClaimed { // This emits an on-chain event to log that a claim was successful, recording the user's address and the amount they received.
            user: user_addr,
            amount: amount,
        });
    }

    fun transfer_from_contract(to: address, amount: u64) acquires ModuleData { //This declares a private helper function (not public entry) that transfers coins from the contract's treasury to an address, and it needs to access the ModuleData resource.
        let module_data = borrow_global<ModuleData>(@pizza_drop); // This fetches a read-only reference to the ModuleData resource stored at the module's account address (@pizza_drop).
        let resource_signer = account::create_signer_with_capability(&module_data.signer_cap); // This is the most crucial line: it uses a special permission (a signer_capability) stored in ModuleData to create a signer for the resource account, allowing the contract to sign transactions on behalf of that account.
        
        // Transfer APT from resource account to user
        coin::transfer<AptosCoin>(&resource_signer, to, amount); // This performs the transfer: it moves the specified amount of AptosCoin from the resource account (controlled by resource_signer) to the recipient's address (to).
    }
    
    #[randomness]
    entry fun get_random_slice(user_addr: address) acquires ModuleData, State { // This declares an entry function that determines a random reward amount for a user, requiring access to the ModuleData and State resources.
        let state = borrow_global_mut<State>(get_resource_address()); // This fetches a mutable reference to the State resource so the function can update its data.
        let time = timestamp::now_microseconds(); // This gets the current blockchain timestamp in microseconds and uses it as a simple, but predictable, source of "randomness".
        let random_val = time % 401; // This calculates a pseudo-random number between 0 and 400 by taking the remainder of the timestamp divided by 401.
        let random_amount = 100 + random_val;  // 100-500 APT (in Octas: 10^8 smallest unit) // This sets the final reward amount to a value between 100 and 500 by adding the base (100) to the random value (0-400), and the comment clarifies the unit is the smallest fraction of APT (10^-8 APT).
        table::add(&mut state.users_claimed_amount, user_addr, random_amount); // This stores the calculated random amount in a table within the State resource, mapping it to the user's address for them to claim later.
    }

    #[view]
    fun get_resource_address(): address acquires ModuleData { // This declares a private function that returns an address and needs to read from the ModuleData resource.
        let module_data = borrow_global<ModuleData>(@pizza_drop); // This fetches a read-only reference to the ModuleData resource stored at the module's account address (@pizza_drop).
        let resource_signer = account::create_signer_with_capability(&module_data.signer_cap); // This line uses the signer capability (signer_cap) stored in the ModuleData to programmatically create a signer for the resource account that this module controls.
        signer::address_of(&resource_signer) // This extracts and returns the blockchain address of the resource account from the created signer object.
    }

    #[view]
    public fun is_registered(user: address): bool acquires ModuleData, State { // This declares a public function (not an entry point) that takes a user's address and returns a boolean (true/false), and it needs to read from the ModuleData and State resources.
        let state = borrow_global<State>(get_resource_address()); // This fetches a read-only reference to the State resource stored at the module's resource account address.
        table::contains(&state.users_claimed_amount, user); //This checks if the provided user's address exists as a key in the users_claimed_amount table within the state, returning true if found (meaning they are registered) and false if not.
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
