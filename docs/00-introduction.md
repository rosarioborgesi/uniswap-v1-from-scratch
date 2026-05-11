# Introduction

This repository documents the process of rebuilding Uniswap V1 from scratch using Solidity and Foundry.

---

# Why Build Uniswap V1?

Uniswap V1 is one of the most important protocols in DeFi history.

Users can trade assets directly against a liquidity pool instead of relying on a traditional order book.

The protocol uses the constant product formula:

$$
x \cdot y = k
$$

where:
- `x` = reserve of asset X
- `y` = reserve of asset Y
- `k` = constant invariant

---

# Repository Structure

```text
src/      → Solidity smart contracts
test/     → Foundry tests
script/   → Deployment and interaction scripts
docs/     → Technical documentation and development notes
```

---