# Token → ETH Input Swap

In an exact input swap:
- the user specifies the exact token amount sold
- the protocol calculates the ETH output

Example:

```text
Sell exactly 1000 DAI
Receive as much ETH as possible
```

---

# Token → ETH Input Swap Flow

The user-facing functions are:

```solidity
tokenToEthSwapInput()
tokenToEthTransferInput()
```

Both functions reuse:

```solidity
_tokenToEthInput()
```

which internally calls:

```solidity
_getInputPrice()
```

Flow:

```text
tokenToEthSwapInput()
        |
        | OR
        |
tokenToEthTransferInput()
        |
        v
_tokenToEthInput()
        |
        v
_getInputPrice()
```

---

# Function Architecture

The implementation order is:

```text
1. getTokenToEthInputPrice()
2. _tokenToEthInput()
3. tokenToEthSwapInput()
4. tokenToEthTransferInput()
```

The AMM pricing logic itself is already implemented inside:

```solidity
_getInputPrice()
```

---

# `getTokenToEthInputPrice()`

```solidity
function getTokenToEthInputPrice(uint256 _tokensSold)
```

This is the public quote function.

It returns how much ETH would be received for a given token input.

It does not execute the swap.

---

# Reserve Order

For Token → ETH swaps:

```text
input reserve  = token reserve
output reserve = ETH reserve
```

So the pricing calculation becomes:

```solidity
_getInputPrice(
    _tokensSold,
    tokenReserve,
    ethReserve
);
```

---

# `_tokenToEthInput()`

```solidity
function _tokenToEthInput(...)
```

This is the internal Token → ETH swap execution function.

Responsibilities:
- validate inputs
- read reserves
- calculate ETH output
- check slippage protection
- send ETH
- transfer tokens
- emit events

---

# ETH Output

The ETH bought is calculated using:

```solidity
uint256 ethBought =
    _getInputPrice(
        _tokensSold,
        tokenReserve,
        ethReserve
    );
```

---

# Slippage Protection

The user specifies:

```solidity
_minEth
```

If:

```solidity
ethBought < _minEth
```

the transaction reverts.

This protects users from:
- front-running
- reserve changes
- excessive slippage

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
    _tokensSold
);
```

The buyer must approve the exchange before executing the swap.

---

# `tokenToEthSwapInput()`

```solidity
function tokenToEthSwapInput(...)
```

The caller:
- provides tokens
- receives ETH directly

Internally:

```text
buyer = msg.sender
recipient = msg.sender
```

---

# `tokenToEthTransferInput()`

```solidity
function tokenToEthTransferInput(...)
```

The caller:
- provides tokens
- another address receives ETH

Internally:

```text
buyer = msg.sender
recipient = _recipient
```

This is useful for:
- payments
- integrations
- smart contract interactions

---

# Flow Summary

The Token → ETH input flow becomes:

```text
Validate inputs
        ↓
Read reserves
        ↓
Calculate ETH bought
        ↓
Validate minimum ETH
        ↓
Send ETH
        ↓
Transfer tokens
```