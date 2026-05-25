# Remove Liquidity

The `removeLiquidity` function allows liquidity providers to burn their LP tokens and withdraw their proportional share of the pool reserves.

Liquidity providers receive LP tokens when calling:

```solidity
addLiquidity()
```

Removing liquidity performs the opposite operation:

```text
Burn LP tokens
        ↓
Withdraw ETH
        ↓
Withdraw ERC20 tokens
```

---

# The removeLiquidity function

The core function is:

```solidity
function removeLiquidity(
    uint256 _amount,
    uint256 _minEth,
    uint256 _minTokens,
    uint256 _deadline
)
    external
    returns (uint256 ethAmount, uint256 tokenAmount)
```

Parameters:

- `_amount` → amount of LP tokens to burn
- `_minEth` → minimum amount of ETH the user is willing to receive
- `_minTokens` → minimum amount of tokens the user is willing to receive
- `_deadline` → timestamp after which the transaction becomes invalid

The function returns:

```text
ETH amount withdrawn
Token amount withdrawn
```

---

# LP ownership

LP tokens represent ownership of the liquidity pool.

Example:

```text
Pool reserves:
10 ETH
20,000 DAI

Total LP supply:
10 ether LP units
```

If Alice owns:

```text
1 ether LP units
```

then she owns:

$$
\frac{1}{10} = 10\%
$$

of the pool.

Removing liquidity burns LP tokens and returns the corresponding percentage of reserves.

So if Alice burns `1 ether` LP units, she receives approximately:

```text
1 ETH
2,000 DAI
```

---

# ETH amount calculation

The ETH withdrawn is proportional to the LP tokens burned.

Formula:

$$
\text{ethAmount} =
\frac{
\text{liquidityBurned} \cdot \text{ethReserve}
}{
\text{totalLiquidity}
}
$$

Where:

- `liquidityBurned` = LP tokens burned
- `ethReserve` = current ETH reserve
- `totalLiquidity` = total LP token supply

---

# Token amount calculation

The token amount withdrawn follows the same logic.

Formula:

$$
\text{tokenAmount} =
\frac{
\text{liquidityBurned} \cdot \text{tokenReserve}
}{
\text{totalLiquidity}
}
$$

Where:

- `tokenReserve` = current token reserve

This guarantees that liquidity providers withdraw assets proportionally to their ownership share.

---

# Example

Suppose the pool contains:

```text
10 ETH
20,000 DAI
10 LP tokens
```

Alice owns:

```text
1 LP token
```

which represents:

```text
10% of the pool
```

If Alice removes liquidity by burning:

```text
1 LP token
```

she receives:

$$
\frac{1 \cdot 10}{10} = 1\ \text{ETH}
$$

and:

$$
\frac{1 \cdot 20000}{10} = 2000\ \text{DAI}
$$

---

# Burning LP tokens

The exchange contract acts as the LP token contract by inheriting from ERC20.

Liquidity removal burns LP tokens using:

```solidity
_burn(msg.sender, _amount);
```

This decreases:

```solidity
totalSupply()
```

and removes the provider ownership share from the pool.

---

# Slippage protection

The function includes two protections:

```solidity
_minEth
```

Minimum acceptable ETH withdrawn.

and:

```solidity
_minTokens
```

Minimum acceptable tokens withdrawn.

If the calculated amounts are lower than these limits, the transaction reverts.

This protects users from reserve changes and front-running.

---

# Deadline protection

The function also receives:

```solidity
_deadline
```

The transaction becomes invalid after the specified timestamp:

```solidity
if (_deadline <= block.timestamp)
```

This prevents transactions from being executed later under different market conditions.

---

# Reserve updates

Removing liquidity decreases both reserves proportionally:

```text
ETH reserve decreases
Token reserve decreases
LP supply decreases
```

Unlike swaps, liquidity removal does not change the reserve ratio.

---

# Flow summary

The remove liquidity flow becomes:

```text
Burn LP tokens
        ↓
Compute ETH amount
        ↓
Compute token amount
        ↓
Validate minimum outputs
        ↓
Transfer ETH
        ↓
Transfer tokens
```

---

# Next step

Now that we understand the math and the flow, the next step is implementing:

```solidity
removeLiquidity()
```

inside the exchange contract.