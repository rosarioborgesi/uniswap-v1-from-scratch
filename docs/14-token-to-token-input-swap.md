# Token → Token Input Swap

A Token → Token input swap allows a user to sell an exact amount of one ERC20 token and receive another ERC20 token.

Example:

```text
Sell exactly 1,000 DAI
Receive as much USDC as possible
```

Unlike ETH → Token or Token → ETH swaps, Uniswap V1 does not swap directly between two ERC20 tokens.

Instead, it routes the trade through ETH.

```text
Token A → ETH → Token B
```

Example:

```text
DAI → ETH → USDC
```

---

# Why ETH Is Used As The Intermediate Asset

Each Uniswap V1 exchange only supports one pair:

```text
ETH <-> ERC20 token
```

So there is no direct DAI/USDC pool.

Instead, a Token → Token swap is composed of two swaps:

```text
DAI → ETH
ETH → USDC
```

This means:
- the source exchange converts Token A into ETH
- the destination exchange converts ETH into Token B

The factory is used to find the destination exchange.

---

# Token → Token Input Flow

For the exact input flow, the user specifies:

```text
exact amount of Token A sold
minimum amount of Token B accepted
minimum amount of ETH accepted as intermediate output
deadline
output token address
```

The output token address is used to find the destination exchange through the factory.

---

# Call Flow

The public user-facing functions are:

```solidity
tokenToTokenSwapInput()
tokenToTokenTransferInput()
```

Both functions reuse the same internal logic:

```solidity
_tokenToTokenInput()
```

The call flow is:

```text
tokenToTokenSwapInput()
        |
        | OR
        |
tokenToTokenTransferInput()
        |
        v
factory.getExchange(outputToken)
        |
        v
_tokenToTokenInput()
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

# tokenToTokenSwapInput()

This function is used when the caller wants to receive the output tokens directly.

```text
buyer = msg.sender
recipient = msg.sender
```

The caller sells Token A and receives Token B.

---

# tokenToTokenTransferInput()

This function is used when the caller wants to send the output tokens to another address.

```text
buyer = msg.sender
recipient = _recipient
```

The caller sells Token A, but `_recipient` receives Token B.

---

# Internal Function

The shared internal function is:

```solidity
_tokenToTokenInput()
```

It receives:

```text
tokens sold
minimum tokens bought
minimum ETH bought
deadline
buyer
recipient
destination exchange
```

Its responsibilities are:

```text
validate inputs
validate destination exchange
calculate ETH bought from Token A
check minimum ETH output
transfer Token A from buyer
call destination exchange
send ETH to destination exchange
receive Token B for recipient
emit event
```

---

# First Swap: Token A → ETH

The source exchange calculates how much ETH is bought by selling Token A.

For Token → ETH:

```text
input reserve  = Token A reserve
output reserve = ETH reserve
```

So the pricing call is:

```solidity
uint256 ethBought = _getInputPrice(
    tokensSold,
    tokenReserve,
    ethReserve
);
```

The user protects this step with:

```solidity
_minEthBought
```

If the calculated ETH output is lower than `_minEthBought`, the transaction reverts.

---

# Second Swap: ETH → Token B

After calculating the ETH output, the source exchange sends that ETH to the destination exchange.

The destination exchange then executes:

```solidity
ethToTokenTransferInput()
```

This performs the second swap:

```text
ETH → Token B
```

and sends Token B to the final recipient.

---

# Slippage Protection

Token → Token input swaps use two minimum values.

---

## Minimum ETH Bought

```solidity
_minEthBought
```

Protects the intermediate swap:

```text
Token A → ETH
```

---

## Minimum Tokens Bought

```solidity
_minTokensBought
```

Protects the final swap:

```text
ETH → Token B
```

Together they protect the user from bad execution across both legs of the route.

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

# Implementation Order

We will implement the input flow in this order:

```text
1. factory.getExchange(outputToken)
2. _tokenToTokenInput()
3. tokenToTokenSwapInput()
4. tokenToTokenTransferInput()
```

---

# Flow Summary

The full Token → Token input swap flow becomes:

```text
User sells exact Token A amount
        ↓
Source exchange calculates ETH bought
        ↓
Validate minimum ETH output
        ↓
Transfer Token A from user
        ↓
Send ETH to destination exchange
        ↓
Destination exchange buys Token B
        ↓
Token B is sent to recipient
```