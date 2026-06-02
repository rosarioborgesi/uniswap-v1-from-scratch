# Uniswap V1 From Scratch

A from-scratch Solidity implementation of the core Uniswap V1 protocol, built with Foundry and documented step by step.

This repository is both an engineering project and a protocol study. The contracts follow the original Uniswap V1 design closely, while modernizing the implementation for Solidity `0.8.x` and OpenZeppelin-based ERC20 primitives.

## What This Project Demonstrates

- Rebuilding a production DeFi primitive from first principles.
- Implementing AMM pricing with the constant product formula.
- Designing ETH/ERC20 liquidity pools and ERC20 LP shares.
- Supporting exact-input and exact-output swaps.
- Routing token-to-token swaps through ETH, as Uniswap V1 does.
- Writing focused unit tests, integration tests, fuzz tests, and invariant tests.
- Documenting protocol behavior, formulas, edge cases, and implementation decisions.

## Protocol Scope

The implementation covers the main Uniswap V1 exchange and factory behavior:

- ETH -> token swaps
- Token -> ETH swaps
- Token -> token swaps through the destination exchange
- Token -> exchange swap variants
- Exact-input and exact-output swap flows
- Liquidity provision
- Liquidity removal
- ERC20 LP token minting, burning, and transfers
- Factory deployment and exchange registry
- Slippage and deadline protection
- Pricing helpers for input and output quotes

## Modern Solidity Choices

The original Uniswap V1 contracts were written for an older Solidity version and used Vyper in production. This project keeps the V1 mechanics while applying modern Solidity practices:

- Solidity `0.8.30` with built-in overflow checks.
- OpenZeppelin `ERC20` for LP token behavior.
- Custom errors instead of revert strings.
- Immutable references for token and factory dependencies.
- Explicit validation modifiers for deadlines, recipients, and exchange addresses.
- Clear contract and function layout conventions.
- Foundry-native tests and configuration.

## Architecture

```text
src/
├── UniswapV1Exchange.sol   # AMM pool, swap logic, liquidity logic, LP ERC20 token
└── UniswapV1Factory.sol    # Exchange deployment and token/exchange registry
```

### Exchange

`UniswapV1Exchange` is the core AMM contract. Each exchange is bound to one ERC20 token and pairs that token against ETH.

The exchange:

- Holds ETH and token reserves.
- Calculates prices using the V1 fee-adjusted constant product formula.
- Mints LP tokens when liquidity is added.
- Burns LP tokens when liquidity is removed.
- Executes ETH -> token, token -> ETH, and token -> token swaps.
- Exposes quote functions for exact-input and exact-output trades.

### Factory

`UniswapV1Factory` creates and tracks one exchange per token.

The factory:

- Deploys new exchange contracts.
- Prevents duplicate exchanges for the same token.
- Maps token addresses to exchanges.
- Maps exchange addresses back to tokens.
- Tracks token IDs and the total number of listed tokens.

## AMM Formula

Uniswap V1 uses the constant product invariant:

```text
x * y = k
```

where:

- `x` is the input asset reserve.
- `y` is the output asset reserve.
- `k` is the product that should not decrease after a swap.

The implementation applies the V1 `0.3%` fee by multiplying the input amount by `997 / 1000` inside the pricing formulas.

Exact-input swaps answer:

```text
How many output tokens do I receive for this input amount?
```

Exact-output swaps answer:

```text
How much input do I need to buy this exact output amount?
```

## Testing Strategy

The test suite is organized by confidence level and behavior type.

```text
test/
├── unit/
│   ├── EthToTokenSwapUnitTest.t.sol
│   ├── LiquidityProvidingUnitTest.t.sol
│   ├── TokenToEthSwapUnitTest.t.sol
│   ├── TokenToTokenSwapUnitTest.t.sol
│   ├── UniswapV1ExchangeUnitTest.t.sol
│   └── UniswapV1FactoryUnitTest.t.sol
├── integration/
│   ├── EthToTokenSwapIntegrationTest.t.sol
│   ├── LiquidityPoolIntegrationTest.t.sol
│   ├── TokenToEthSwapIntegrationTest.t.sol
│   ├── TokenToExchangeSwapIntegrationTest.t.sol
│   ├── TokenToTokenSwapIntegrationTest.t.sol
│   └── UniswapV1IntegrationTest.t.sol
├── fuzz/
│   └── UniswapV1ExchangeFuzzTest.t.sol
└── invariant/
    ├── UniswapV1ExchangeHandler.t.sol
    └── UniswapV1ExchangeInvariants.t.sol
```

### Unit Tests

Unit tests validate individual behaviors and revert paths, including:

- Constructor validation.
- Factory exchange creation.
- Pricing formula correctness.
- Swap input and output flows.
- Transfer variants.
- Liquidity minting and burning.
- Slippage, deadline, recipient, and reserve validation.

### Integration Tests

Integration tests exercise complete user flows across deployed exchanges:

- Default ETH receive swap behavior.
- Liquidity pool lifecycle.
- ETH -> token swaps.
- Token -> ETH swaps.
- Token -> token swaps.
- Token -> exchange variants.

### Fuzz Tests

Fuzz tests stress the AMM math across many generated inputs:

- Input price matches the constant product formula.
- Output price matches the constant product formula.
- Adding liquidity mints the expected LP amount.
- Adding liquidity preserves reserve ratios.
- Removing liquidity returns proportional reserves.
- Removing liquidity updates reserves and LP supply consistently.

### Invariant Tests

Invariant tests use a handler contract with ghost variables to track expected reserves across stateful liquidity actions.

Current invariant coverage checks that:

- The exchange ETH balance matches the expected ETH reserve.
- The exchange token balance matches the expected token reserve.

## Documentation

The `docs/` directory explains the protocol incrementally, from AMM fundamentals to full token-to-token routing.

```text
docs/
├── 00-introduction.md
├── 01-project-setup.md
├── 02-uniswap-v1-architecture.md
├── 03-constant-product-formula.md
├── 04-eth-to-token-swap.md
├── 05-eth-to-token-input-swap.md
├── 06-eth-to-token-output-swap.md
├── 07-liquidity-providing.md
├── 08-add-liquidity.md
├── 09-remove-liquidity.md
├── 10-token-to-eth-swap.md
├── 11-token-to-eth-input-swap.md
├── 12-token-to-eth-output-swap.md
├── 13-factory.md
├── 14-token-to-token-input-swap.md
├── 15-token-to-token-output-swap.md
└── 16-token-to-exchange-variants.md
```

These notes are written to show the reasoning behind the code, not only the final implementation.

## Project Structure

```text
.
├── src/                  # Solidity protocol contracts
├── test/                 # Unit, integration, fuzz, and invariant tests
├── docs/                 # Protocol notes and implementation walkthroughs
├── lib/                  # Foundry dependencies
├── foundry.toml          # Foundry configuration
├── foundry.lock          # Dependency lockfile
└── README.md
```

## Getting Started

Install dependencies:

```bash
forge install
```

Build the contracts:

```bash
forge build
```

Run the full test suite:

```bash
forge test
```

Run tests with gas reporting:

```bash
forge test --gas-report
```

Run invariant tests only:

```bash
forge test --match-path test/invariant/*
```

## Reference

This implementation is inspired by the original Uniswap V1 contracts:

- https://github.com/Uniswap/v1-contracts/tree/master

The goal is not to copy the original contracts line by line, but to rebuild the protocol mechanics in modern Solidity while documenting the design and test process.

## Connect With Me

<p align="left">
  <a href="https://x.com/rosarioborgesi">
    <img src="https://img.shields.io/badge/twitter-000000?style=for-the-badge&logo=x&logoColor=white"/>
  </a>
  <a href="https://www.linkedin.com/in/rosarioborgesi/">
    <img src="https://img.shields.io/badge/LinkedIn-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white"/>
  </a>
  <a href="mailto:borgesiros@gmail.com">
    <img src="https://img.shields.io/badge/Email-D14836?style=for-the-badge&logo=gmail&logoColor=white"/>
  </a>
  <a href="https://www.youtube.com/@rosarioborgesi">
    <img src="https://img.shields.io/badge/YouTube-FF0000?style=for-the-badge&logo=youtube&logoColor=white"/>
  </a>
  <a href="https://farcaster.xyz/rosarioborgesi">
    <img src="https://img.shields.io/badge/Farcaster-855DCD?style=for-the-badge"/>
  </a>
  <a href="https://medium.com/@rosarioborgesi/">
    <img src="https://img.shields.io/badge/Medium-000000?style=for-the-badge&logo=medium&logoColor=white"/>
  </a>
</p>
