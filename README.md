# First Flight #1: PizzaDrop

## Contest Details
- 2x XP/Finding!
  
- High - 200xp
- Medium - 40xp
- Low - 4xp

Starts: TBD
Ends: TBD

## Stats
- nSLOC: ~125
- Complexity Score: 35

[//]: # (contest-details-open)

# 🍕 **PizzaDrop Challenge**

## **📖 Story**
PizzaCoin is launching and wants to share pizza slices with their community using **Aptos Coin (APT)**! Any pizza lover can register and claim a random slice size between 100-500 APT. It's first come, first served - but everyone gets a random surprise!

---

## **👥 Participants & Rules**

### **🍕 Pizza Lovers (Community Members)**
- Must be registered by the owner to become eligible
- Can claim PizzaDrop **once** after registration  
- Receive random amount: **100-500 APT** 
- *"Every pizza lover deserves a random slice!"*

### **🏪 PizzaCoin Team (Contract Owner)**
- Can register pizza lovers
- Can fund the PizzaDrop pool with APT
- Manages the airdrop distribution
- Controls who gets access to pizza slices

---

## **⚖️ Smart Contract Rules**

1. **Register First**: Owner must register pizza lovers before they can claim
2. **One Slice Per Person**: Each address can claim exactly once
3. **Random Slice Size**: 100-500 APT randomly determined
4. **Pool Must Have Pizza**: Cannot claim if pool has insufficient APT
5. **APT-Based**: Uses native Aptos Coin


[//]: # (contest-details-close)

[//]: # (getting-started-open)
## Getting Started

## Requirements
- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - You'll know you did it right if you can run `git --version` and you see a response like `git version x.x.x`
- [Aptos CLI](https://aptos.dev/tools/aptos-cli/)
  - You'll know you did it right if you can run `aptos --version` and you see a response like `aptos 3.x.x`
- [Move](https://aptos.dev/move/move-on-aptos/)

## Quickstart
```bash
git clone https://github.com/EmanHerawy/aptos-first-flight
cd aptos-first-flight/pizza_drop
aptos move compile --dev
```

## Usage

### Deploy (local)
1. Start a local Aptos node
```bash
aptos node run-local-testnet --with-faucet
```

2. Initialize your account
```bash
aptos init --profile local --network local
```

3. Fund your account
```bash
aptos account fund-with-faucet --profile local
```

4. Deploy
```bash
aptos move publish --profile local --named-addresses pizza_drop=local
```

## Testing
```bash
# Run all tests
aptos move test --named-addresses pizza_drop=0x123

# Run specific test
aptos move test --named-addresses pizza_drop=0x123 -f "test_pizza_drop_with_apt"

# Run with coverage
aptos move test --coverage --named-addresses pizza_drop=0x123
```

[//]: # (getting-started-close)

[//]: # (scope-open)
## Scope
- In Scope:
```
./sources/
└── pizza_drop.move
./Move.toml
```

## Compatibilities
- Move Version: Latest
- Chain(s) to deploy contract to: Aptos Mainnet/Testnet/Devnet
- Aptos CLI Version: 3.x.x
- Uses: `aptos_framework::coin`, `aptos_framework::account`, `aptos_std::table`

[//]: # (scope-close)

## Known Issues
[//]: # (known-issues-open)
<p align="center">
No known issues reported.
</p>
[//]: # (known-issues-close)

### This challenge teaches several important security concepts:

- How Move handles access control and ownership verification
- Resource account management and signer capabilities
- APT (Aptos Coin) integration and transfer security
- Randomness implementation using `#[randomness]` attribute
- State management with global storage and tables
- Economic logic verification (airdrop mechanics)
- Balance tracking consistency (internal vs actual balances)
- Prevention of double-spending and multiple claims
 