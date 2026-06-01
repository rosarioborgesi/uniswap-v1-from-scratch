# Token → Exchange Variants

Uniswap V1 also exposes Token → Exchange swap functions.

These functions are very similar to Token → Token swaps.

The main difference is how the destination exchange is selected.

---

# Token → Token vs Token → Exchange

In the normal Token → Token flow, the user provides the output token address.

Example:

```solidity
tokenToTokenSwapInput(
    tokensSold,
    minTokensBought,
    minEthBought,
    deadline,
    tokenAddr
);
```

The exchange then asks the factory:

```solidity
factory.getExchange(tokenAddr)
```

to find the destination exchange.

---

# Token → Exchange Flow

In the Token → Exchange variants, the user provides the destination exchange address directly.

Example:

```solidity
tokenToExchangeSwapInput(
    tokensSold,
    minTokensBought,
    minEthBought,
    deadline,
    exchangeAddr
);
```

So instead of:

```text
token address → factory → exchange address
```

the user directly provides:

```text
exchange address
```

---

# Why These Functions Exist

The Token → Exchange variants allow swaps through exchanges that may not come from the same factory.

This makes the protocol more flexible.

For example:

```text
Token A Exchange
        ↓
External Token B Exchange
```

The source exchange does not need to query its own factory to find the destination exchange.

Instead, the caller provides the exchange address directly.

---

# Swap Route

The route is still the same:

```text
Token A → ETH → Token B
```

The only difference is that the destination exchange is passed directly instead of being found through the factory.

---

# Input Variants

For exact input swaps, Uniswap V1 exposes:

```solidity
tokenToExchangeSwapInput()
tokenToExchangeTransferInput()
```

These reuse the same internal function used by Token → Token input swaps:

```solidity
_tokenToTokenInput()
```

---

# tokenToExchangeSwapInput()

This function is used when the caller wants to receive the output tokens directly.

```text
buyer = msg.sender
recipient = msg.sender
```

The caller sells an exact amount of Token A and receives as many Token B as possible.

---

# tokenToExchangeTransferInput()

This function is used when the caller wants to send the output tokens to another address.

```text
buyer = msg.sender
recipient = _recipient
```

The caller sells Token A, but `_recipient` receives Token B.

---

# Output Variants

For exact output swaps, Uniswap V1 exposes:

```solidity
tokenToExchangeSwapOutput()
tokenToExchangeTransferOutput()
```

These reuse the same internal function used by Token → Token output swaps:

```solidity
_tokenToTokenOutput()
```

---

# tokenToExchangeSwapOutput()

This function is used when the caller wants to receive an exact amount of output tokens directly.

```text
buyer = msg.sender
recipient = msg.sender
```

The caller sells up to a maximum amount of Token A and receives exactly Token B.

---

# tokenToExchangeTransferOutput()

This function is used when the caller wants to send the exact output tokens to another address.

```text
buyer = msg.sender
recipient = _recipient
```

The caller sells Token A, but `_recipient` receives Token B.

---

# Validation

The destination exchange must be valid.

It cannot be:

```text
zero address
the current exchange
```

This prevents:
- routing to no exchange
- routing back to the same exchange

For transfer variants, the recipient must also be valid.

The recipient cannot be:

```text
zero address
the current exchange
```

---

# Why They Reuse The Same Internal Logic

The Token → Exchange variants do not need new swap logic.

They only change how the destination exchange is provided.

```text
Token → Token
        ↓
destination exchange comes from factory

Token → Exchange
        ↓
destination exchange is passed directly
```

Both flows still execute through:

```text
Token A → ETH → Token B
```

So they can reuse:

```solidity
_tokenToTokenInput()
_tokenToTokenOutput()
```

---

# Flow Summary

The Token → Exchange input flow is:

```text
User sells exact Token A amount
        ↓
User provides destination exchange
        ↓
Source exchange calculates ETH bought
        ↓
Source exchange sends ETH to destination exchange
        ↓
Destination exchange sends Token B to recipient
```

The Token → Exchange output flow is:

```text
User requests exact Token B output
        ↓
User provides destination exchange
        ↓
Destination exchange calculates required ETH
        ↓
Source exchange calculates required Token A
        ↓
Source exchange sends ETH to destination exchange
        ↓
Destination exchange sends Token B to recipient
```

