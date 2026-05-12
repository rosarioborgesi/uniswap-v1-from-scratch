# Uniswap V1 Architecture

Uniswap V1 is composed of:
- a Factory contract
- multiple Exchange contracts

Each Exchange contract is associated with a single ERC20 token.

Pools are always:

ETH <-> ERC20

Example:

ETH <-> DAI
ETH <-> USDC

Token-to-token swaps are performed through ETH.

Example:

DAI -> ETH -> USDC

---

# Factory Contract

The Factory contract:
- creates new exchanges
- stores the mapping between tokens and exchanges

---

# Exchange Contract

Each Exchange contract:
- stores liquidity reserves
- allows swaps
- allows adding liquidity
- allows removing liquidity

---

# Liquidity Pools

Liquidity pools contain:
- ETH
- ERC20 tokens

Users called Liquidity Providers (LPs) deposit assets into the pool and receive LP tokens representing a share of the pool.