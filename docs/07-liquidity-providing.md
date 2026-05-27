# Liquidity Providing

Our exchange currently supports:

```text
ETH → Token swaps
```

but the exchange itself does not magically own ETH or tokens.

Someone must deposit assets into the pool so traders can swap against them.

These users are called:

```text
Liquidity Providers (LPs)
```

Liquidity providers deposit:

```text
ETH + ERC20 tokens
```

into the AMM reserves.

In return they receive:
- ownership of the pool
- trading fees
- LP tokens representing their share

---

# AMM Reserves

The exchange maintains two reserves:

```text
ETH reserve
Token reserve
```

The AMM invariant is:

$$
x \cdot y = k
$$

Where:
- `x` = ETH reserve
- `y` = token reserve

Swaps modify the reserves while preserving the invariant.

Liquidity providers increase or decrease both reserves proportionally.

---

# First Liquidity Provider

Initially the pool is empty:

```text
ETH reserve = 0
Token reserve = 0
```

This means there is no market price yet.

The first liquidity provider defines the initial exchange rate.

Example:

```text
10 ETH + 20,000 DAI
```

defines:

```text
1 ETH = 2000 DAI
```

This becomes the starting market price of the pool.

---

# Subsequent Liquidity Providers

Once the pool has been initialized, new providers cannot deposit arbitrary amounts.

They must deposit liquidity proportionally to the current reserve ratio.

Example:

```text
Pool reserves:
10 ETH
20,000 DAI
```

Current ratio:

```text
1 ETH = 2000 DAI
```

If a user deposits:

```text
1 ETH
```

they must also deposit:

```text
2000 DAI
```

Otherwise the pool price would change.

---

# LP Tokens

Liquidity providers need a way to track ownership of the pool.

Uniswap V1 models liquidity shares as ERC20 tokens.

The exchange contract itself acts as the LP token contract.

Liquidity providers receive LP tokens when adding liquidity and burn LP tokens when removing liquidity.

---

# LP Ownership

LP tokens represent proportional ownership of the pool.

Example:

```text
Pool:
10 ETH
20,000 DAI

Total LP supply:
10 LP tokens
```

If Alice owns:

```text
1 LP token
```

then she owns:

```text
10% of the pool
```

When liquidity is removed, LP tokens are burned and the provider receives the corresponding percentage of reserves.

---

# Why LP Tokens Are ERC20

In the original Uniswap V1 implementation, liquidity shares behave like normal ERC20 tokens.

This means LP tokens are:
- transferable
- approvable
- composable with other protocols

In Solidity we can model this by inheriting from OpenZeppelin ERC20:

```solidity
contract UniswapV1Exchange is ERC20
```

This allows the exchange to:
- mint LP tokens
- burn LP tokens
- track total liquidity with `totalSupply()`

---

# Core Liquidity Functions

The liquidity system revolves around two core functions:

```solidity
addLiquidity()
removeLiquidity()
```

---

# addLiquidity()

The `addLiquidity()` function:
- accepts ETH
- transfers ERC20 tokens into the pool
- mints LP tokens
- increases reserves

Flow:

```text
Deposit ETH
        ↓
Deposit tokens
        ↓
Mint LP tokens
```

---

# removeLiquidity()

The `removeLiquidity()` function:
- burns LP tokens
- withdraws ETH
- withdraws ERC20 tokens
- decreases reserves

Flow:

```text
Burn LP tokens
        ↓
Withdraw ETH
        ↓
Withdraw tokens
```

---

# Reserve Storage

The exchange does not need dedicated reserve storage variables.

ETH reserves can be read directly from:

```solidity
address(this).balance
```

Token reserves can be read using:

```solidity
i_token.balanceOf(address(this))
```

This mirrors the original Uniswap V1 implementation.