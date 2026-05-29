# Token → Token Output Swap

A Token → Token output swap allows a user to buy an exact amount of another ERC20 token.

Example:

```text
Buy exactly 100 USDC
Spend at most 1,000 DAI
```

Like the Token → Token input flow, Uniswap V1 routes the swap through ETH:

```text
Token A → ETH → Token B
```

Example:

```text
DAI → ETH → USDC
```

---

# Exact Output Flow

In an exact output swap, the user specifies:

```text
exact amount of Token B bought
maximum amount of Token A sold
maximum amount of ETH used as intermediate asset
deadline
output token address
```

The protocol calculates how much Token A is required.

---

# Why ETH Is Used As The Intermediate Asset

Each Uniswap V1 exchange only supports one pair:

```text
ETH <-> ERC20 token
```

So there is no direct Token A / Token B pool.

A Token → Token output swap is composed of two swaps:

```text
Token A → ETH
ETH → Token B
```

The destination exchange is found through the factory.

---

# Call Flow

The public user-facing functions are:

```solidity
tokenToTokenSwapOutput()
tokenToTokenTransferOutput()
```

Both functions reuse the same internal logic:

```solidity
_tokenToTokenOutput()
```

The call flow is:

```text
tokenToTokenSwapOutput()
        |
        | OR
        |
tokenToTokenTransferOutput()
        |
        v
factory.getExchange(outputToken)
        |
        v
_tokenToTokenOutput()
        |
        v
Destination exchange quotes ETH required
        |
        v
Source exchange calculates Token A required
        |
        v
Token A → ETH
        |
        v
Destination exchange
        |
        v
ETH → Token B
```

---

# tokenToTokenSwapOutput()

This function is used when the caller wants to receive the exact output tokens directly.

```text
buyer = msg.sender
recipient = msg.sender
```

The caller sells up to `_maxTokensSold` of Token A and receives exactly `_tokensBought` of Token B.

---

# tokenToTokenTransferOutput()

This function is used when the caller wants to send the exact output tokens to another address.

```text
buyer = msg.sender
recipient = _recipient
```

The caller sells Token A, but `_recipient` receives Token B.

---

# Internal Function

The shared internal function is:

```solidity
_tokenToTokenOutput()
```

It receives:

```text
tokens bought
maximum tokens sold
maximum ETH sold
deadline
buyer
recipient
destination exchange
```

Its responsibilities are:

```text
validate inputs
validate destination exchange
ask destination exchange how much ETH is required
calculate how many Token A are required
check max ETH protection
check max Token A protection
transfer Token A from buyer
call destination exchange
send ETH to destination exchange
receive Token B for recipient
emit event
```

---

# First Step: How Much ETH Is Needed?

The destination exchange knows how much ETH is required to buy the exact Token B output.

So the source exchange calls:

```solidity
getEthToTokenOutputPrice(_tokensBought)
```

on the destination exchange.

This returns:

```text
ETH required to buy exact Token B output
```

This is the intermediate ETH amount.

---

# Second Step: How Many Token A Are Needed?

After knowing how much ETH is required, the source exchange calculates how many Token A are needed to buy that ETH.

For Token A → ETH:

```text
input reserve  = Token A reserve
output reserve = ETH reserve
```

So the pricing call is:

```solidity
uint256 tokensSold = _getOutputPrice(
    ethBought,
    tokenReserve,
    ethReserve
);
```

Where:

- `ethBought` = ETH needed by the destination exchange
- `tokenReserve` = Token A reserve in the source exchange
- `ethReserve` = ETH reserve in the source exchange

---

# Slippage Protection

Token → Token output swaps use two maximum values.

---

## Maximum ETH Sold

```solidity
_maxEthSold
```

Limits the ETH used as the intermediate asset.

If the destination exchange requires more ETH than `_maxEthSold`, the transaction reverts.

---

## Maximum Tokens Sold

```solidity
_maxTokensSold
```

Limits how many Token A the user is willing to sell.

If the source exchange requires more Token A than `_maxTokensSold`, the transaction reverts.

Together these protect the user from bad execution across both swap legs.

---

# Destination Exchange Validation

The destination exchange must be valid.

It cannot be:

```text
zero address
the same exchange
```

This prevents:
- routing to no exchange
- swapping a token into itself through the same pool

---

# Execution Flow

The full Token → Token output swap flow becomes:

```text
User requests exact Token B output
        ↓
Source exchange finds destination exchange
        ↓
Destination exchange calculates required ETH
        ↓
Source exchange calculates required Token A
        ↓
Validate max ETH
        ↓
Validate max Token A
        ↓
Transfer Token A from user
        ↓
Send ETH to destination exchange
        ↓
Destination exchange sends Token B to recipient
```

---

# Implementation Order

We will implement the output flow in this order:

```text
1. _tokenToTokenOutput()
2. tokenToTokenSwapOutput()
3. tokenToTokenTransferOutput()
```

The factory lookup is handled by the external wrapper functions, while `_tokenToTokenOutput()` contains the shared execution logic.