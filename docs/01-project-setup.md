# Project Setup

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