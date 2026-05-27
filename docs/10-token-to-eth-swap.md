# Token to ETH Swap

After implementing:

```text
ETH → Token swaps
```

we now implement:

```text
Token → ETH swaps
```

This allows users to:
- sell ERC20 tokens
- receive ETH from the pool

Example:

```text
DAI → ETH
USDC → ETH
WETH → ETH
```

---

# Swap Direction

In this swap direction:

```text
input asset  = ERC20 token
output asset = ETH
```

So:
- token reserve becomes the input reserve
- ETH reserve becomes the output reserve

---

# Exact Input vs Exact Output

Uniswap V1 supports two Token → ETH swap modes.

---

## Exact Input Swap

The user specifies the exact token amount sold.

Example:

```text
Sell exactly 1000 DAI
Receive as much ETH as possible
```

The protocol calculates the ETH output.

---

## Exact Output Swap

The user specifies the exact ETH amount desired.

Example:

```text
Buy exactly 1 ETH
Spend as few tokens as possible
```

The protocol calculates the required token input.

---

# Token → ETH Swap Architecture

The Token → ETH swap flow is divided into:
- pricing functions
- internal swap execution functions
- external user-facing functions

This keeps the implementation modular and reusable.

---

# Token → ETH Input Swap Flow

Exact input swaps use:

```solidity
tokenToEthSwapInput()
tokenToEthTransferInput()
```

Both functions reuse:

```solidity
_tokenToEthInput()
```

which internally uses:

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

# Token → ETH Output Swap Flow

Exact output swaps use:

```solidity
tokenToEthSwapOutput()
tokenToEthTransferOutput()
```

Both functions reuse:

```solidity
_tokenToEthOutput()
```

which internally uses:

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

# Reserve Order

For Token → ETH swaps:

```text
input reserve  = token reserve
output reserve = ETH reserve
```

So pricing functions use:

```solidity
_getInputPrice(
    tokensSold,
    tokenReserve,
    ethReserve
);
```

or:

```solidity
_getOutputPrice(
    ethBought,
    tokenReserve,
    ethReserve
);
```

---

# Why The Implementation Is Incremental

The implementation order is:

```text
pricing functions
        ↓
quote functions
        ↓
internal swap execution
        ↓
external user-facing functions
```

This mirrors the architecture of the original Uniswap V1 implementation.