# Token → ETH Output Swap

In an exact output swap:
- the user specifies the exact ETH output desired
- the protocol calculates the required token input

Example:

```text
Buy exactly 1 ETH
Spend as few DAI as possible
```

---

# Token → ETH Output Swap Flow

The user-facing functions are:

```solidity
tokenToEthSwapOutput()
tokenToEthTransferOutput()
```

Both functions reuse:

```solidity
_tokenToEthOutput()
```

which internally calls:

```solidity
_getOutputPrice()
```

Flow:

```text
tokenToEthSwapOutput()
        |
        | OR
        |
tokenToEthTransferOutput()
        |
        v
_tokenToEthOutput()
        |
        v
_getOutputPrice()
```

---

# Function Architecture

The implementation order is:

```text
1. getTokenToEthOutputPrice()
2. _tokenToEthOutput()
3. tokenToEthSwapOutput()
4. tokenToEthTransferOutput()
```

The AMM pricing logic itself is already implemented inside:

```solidity
_getOutputPrice()
```

---

# Reserve Order

For Token → ETH swaps:

```text
input reserve  = token reserve
output reserve = ETH reserve
```

So the pricing calculation becomes:

```solidity
_getOutputPrice(
    _ethBought,
    tokenReserve,
    ethReserve
);
```

---

# `getTokenToEthOutputPrice()`

```solidity
function getTokenToEthOutputPrice(uint256 _ethBought)
```

This is the public quote function.

It returns how many tokens are required to buy an exact amount of ETH.

It does not execute the swap.

---

# `_tokenToEthOutput()`

```solidity
function _tokenToEthOutput(...)
```

This is the internal exact output swap execution function.

Responsibilities:
- validate inputs
- calculate required token input
- check slippage protection
- send ETH
- transfer tokens
- emit events

---

# Required Tokens

The required token amount is calculated with:

```solidity
uint256 tokensSold =
    _getOutputPrice(
        _ethBought,
        tokenReserve,
        ethReserve
    );
```

---

# Slippage Protection

The user specifies:

```solidity
_maxTokens
```

If:

```solidity
tokensSold > _maxTokens
```

the transaction reverts.

Meaning:

```text
I want exactly this ETH amount,
but I refuse to spend more than this amount of tokens.
```

---

# ETH Transfer

The exchange sends ETH to the recipient using:

```solidity
_recipient.call{value: ethBought}("");
```

If the ETH transfer fails, the transaction reverts.

---

# Token Transfer

The exchange pulls tokens from the buyer using:

```solidity
i_token.transferFrom(
    _buyer,
    address(this),
    tokensSold
);
```

The buyer must approve the exchange before executing the swap.

---

# `tokenToEthSwapOutput()`

```solidity
function tokenToEthSwapOutput(...)
```

The caller:
- requests exact ETH output
- pays tokens
- receives ETH directly

Internally:

```text
buyer = msg.sender
recipient = msg.sender
```

---

# `tokenToEthTransferOutput()`

```solidity
function tokenToEthTransferOutput(...)
```

The caller:
- pays tokens
- another address receives ETH

Internally:

```text
buyer = msg.sender
recipient = _recipient
```

---

# Flow Summary

The Token → ETH output flow becomes:

```text
Validate inputs
        ↓
Read reserves
        ↓
Calculate required tokens
        ↓
Validate max tokens
        ↓
Send ETH
        ↓
Transfer tokens
```