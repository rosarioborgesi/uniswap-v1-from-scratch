# Liquidity Providing

Our exchange currently supports:

```text
ETH → Token swaps
```

but the exchange itself does not magically own tokens or ETH.

Someone must deposit assets into the pool so traders can swap against them.

These users are called:

```text
Liquidity Providers (LPs)
```

They deposit:

```text
ETH + ERC20 tokens
```

into the AMM reserves.

In return they receive a share of the pool and earn trading fees.

---

# The AMM reserves

The exchange keeps track of two reserves:

```text
ETH reserve
Token reserve
```

The constant product formula:

```math
x * y = k
```

must always remain balanced.

Where:

- \(x\) = ETH reserve
- \(y\) = token reserve

Swaps change the reserves but preserve the invariant.

Liquidity providers increase both reserves simultaneously.

---

# First liquidity provider

The very first liquidity provider is special.

Initially the pool is empty:

```text
ETH reserve = 0
Token reserve = 0
```

This means there is no market price yet.

The first LP decides the initial price ratio.

Example:

```text
10 ETH + 20,000 DAI
```

defines:

$$
1\ \text{ETH} = 2000\ \text{DAI}
$$

This becomes the starting market price of the pool.

---

# Subsequent liquidity providers

After the pool has been initialized, new LPs cannot deposit arbitrary amounts.

They must deposit assets proportionally to the current reserves.

Example:

```text
Pool reserves:
10 ETH
20,000 DAI
```

The ratio is:

```text
1 ETH = 2000 DAI
```

If a user adds:

```text
1 ETH
```

they must also add:

```text
2000 DAI
```

Otherwise the pool price would change.

---

# LP shares

Liquidity providers need a way to track ownership of the pool.

Uniswap V1 does this with liquidity shares.

Example:

```text
Pool:
10 ETH + 20,000 DAI

Alice owns 100% of liquidity
```

If Bob adds liquidity equal to 50% of the current pool value:

```text
5 ETH + 10,000 DAI
```

then ownership becomes:

```text
Alice → 66.6%
Bob   → 33.3%
```

These shares are later used to withdraw liquidity.

---

# Core functions we will need

At minimum we will probably implement:

```solidity
function addLiquidity(uint256 _maxTokens)
```

and later:

```solidity
function removeLiquidity(uint256 _liquidityAmount)
```

The add liquidity function will:

- accept ETH
- calculate required token amount
- transfer tokens from the user
- mint liquidity shares

---

# Important design detail

The contract does not need explicit ETH reserve storage because:

```solidity
address(this).balance
```

already represents the ETH reserve.

The token reserve can be read using:

```solidity
i_token.balanceOf(address(this))
```

This is exactly how Uniswap V1 works.

