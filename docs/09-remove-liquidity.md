# Remove Liquidity

The `removeLiquidity()` function allows liquidity providers to burn LP tokens and withdraw their proportional share of the reserves.

Removing liquidity performs the opposite operation of:

```solidity
addLiquidity()
```

Flow:

```text
Burn LP tokens
        ↓
Withdraw ETH
        ↓
Withdraw tokens
```

---

# Function Signature

```solidity
function removeLiquidity(
    uint256 _amount,
    uint256 _minEth,
    uint256 _minTokens,
    uint256 _deadline
)
    external
    returns (
        uint256 ethAmount,
        uint256 tokenAmount
    )
```

Parameters:
- `_amount` → LP tokens to burn
- `_minEth` → minimum ETH expected
- `_minTokens` → minimum tokens expected
- `_deadline` → transaction expiration timestamp

The function returns:
- ETH withdrawn
- tokens withdrawn

---

# ETH Withdrawn

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
- `totalLiquidity` = total LP supply

---

# Tokens Withdrawn

The token amount follows the same logic.

Formula:

$$
\text{tokenAmount} =
\frac{
\text{liquidityBurned} \cdot \text{tokenReserve}
}{
\text{totalLiquidity}
}
$$

This guarantees proportional withdrawals.

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

If Alice burns:

```text
1 LP token
```

she receives approximately:

```text
1 ETH
2,000 DAI
```

---

# Burning LP Tokens

LP tokens are burned using:

```solidity
_burn(msg.sender, _amount);
```

This decreases:
- the provider ownership share
- the total LP supply

---

# Slippage Protection

The function includes two protections.

---

## Minimum ETH Protection

```solidity
if (ethAmount < _minEth)
```

The user refuses to withdraw less ETH than expected.

---

## Minimum Token Protection

```solidity
if (tokenAmount < _minTokens)
```

The user refuses to withdraw fewer tokens than expected.

---

# Deadline Protection

The transaction becomes invalid after:

```solidity
_deadline
```

Implementation:

```solidity
if (_deadline <= block.timestamp)
```

This protects users from reserve changes and delayed execution.

---

# Reserve Updates

Removing liquidity decreases:
- ETH reserve
- token reserve
- LP supply

Unlike swaps, liquidity removal preserves the reserve ratio.

---

# ETH Transfer

ETH is transferred to the provider using:

```solidity
(bool success,) =
    msg.sender.call{value: ethAmount}("");
```

If the transfer fails, the transaction reverts.

---

# Token Transfer

Tokens are transferred using:

```solidity
i_token.transfer(
    msg.sender,
    tokenAmount
);
```

If the transfer fails, the transaction reverts.

---

# Flow Summary

The remove liquidity flow becomes:

```text
Validate inputs
        ↓
Calculate withdrawn amounts
        ↓
Burn LP tokens
        ↓
Transfer ETH
        ↓
Transfer tokens
```