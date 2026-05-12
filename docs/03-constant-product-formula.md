# Constant Product Formula

Uniswap V1 uses the constant product formula:

$$
x \cdot y = k
$$

where:
- `x` = ETH reserve
- `y` = token reserve
- `k` = constant product

---

# How It Works

The pool must keep the product of the two reserves constant.

If a user adds ETH to the pool, the pool must send out tokens.

If a user adds tokens to the pool, the pool must send out ETH.

The reserves change, but the product should remain constant or increase because of fees.

---

# Example

Initial pool:

```text
10 ETH
1,000 tokens
```

The constant product is:

```text
10 * 1,000 = 10,000
```

If a user swaps 1 ETH, the ETH reserve increases:

```text
11 ETH
```

To keep the product close to 10,000, the token reserve becomes:

```text
10,000 / 11 = 909.09 tokens
```

So the user receives approximately:

```text
1,000 - 909.09 = 90.91 tokens
```

---

# Price Impact

The more a user trades against the pool, the more the price moves.

Small trades have low price impact.

Large trades have high price impact.

---

# Fees

Uniswap V1 charges a 0.3% fee on swaps.

Because of the fee, the full input amount is not used to calculate the output amount.

This makes `k` increase over time.

Liquidity providers benefit from this increase.