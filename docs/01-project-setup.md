# Project Setup
The original project of [Uniswap V1](https://github.com/Uniswap/v1-contracts) is written in Vyper.

In this project, we use Solidity and Foundry.

The original Uniswap V1 [`Exchange`](https://github.com/Uniswap/v1-contracts/blob/master/contracts/uniswap_exchange.vy) contract embeds the ERC20 token logic.

In this implementation, we instead use OpenZeppelin contracts for ERC20 tokens.

The project was initialized using:

```bash
forge init uniswap-v1-from-scratch
```

---

# Installing OpenZeppelin Contracts

Install the dependency with:

```bash
forge install OpenZeppelin/openzeppelin-contracts
```

This library will later be used for:
- ERC20 tokens
- LP token implementation
- utilities and interfaces

---

# Update foundry.toml

Added:

```
remappings = [
  "openzeppelin-contracts/=lib/openzeppelin-contracts/contracts/"
]
```

in the foundry.toml file.