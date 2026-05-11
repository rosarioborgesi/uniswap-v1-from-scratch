# Uniswap V1 From Scratch

This repository documents the process of rebuilding Uniswap V1 from scratch using Solidity and Foundry.

The goal of this project is to deeply understand:
- Automated Market Makers (AMMs)
- Liquidity pools
- LP tokens
- Constant product pricing
- Swaps and slippage
- DeFi protocol architecture

The project is built step-by-step as an educational and engineering exercise.

## Tech Stack

- Solidity
- Foundry
- OpenZeppelin Contracts

## Planned Features

- [ ] Exchange contract
- [ ] Add liquidity
- [ ] Remove liquidity
- [ ] ETH → Token swaps
- [ ] Token → ETH swaps
- [ ] LP tokens
- [ ] Factory contract
- [ ] Token → Token swaps
- [ ] Tests with Foundry
- [ ] Fuzzing and invariant testing

# Documentation

A dedicated `docs/` folder is used to document the protocol implementation process step-by-step.

```text
docs/
├── 00-introduction.md
├── 01-project-setup.md
├── 02-uniswap-v1-architecture.md
├── ...
```

## Goal

The purpose of this repository is educational:
to understand how Uniswap V1 works internally by rebuilding it from scratch with modern Solidity tooling.