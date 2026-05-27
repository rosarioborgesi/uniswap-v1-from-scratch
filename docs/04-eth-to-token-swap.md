# ETH to Token Swap

In this first version we focus on the core AMM logic for:

```text
ETH → ERC20 token
```

Each Uniswap V1 exchange is linked to a single ERC20 token.

Example:

```text
ETH <-> DAI
ETH <-> USDC
ETH <-> WETH
```

The goal is to understand:
- swap pricing
- reserve updates
- exact input swaps
- exact output swaps
- slippage protection
- AMM execution flow

---

# Exchange Token

Each exchange trades ETH against a single ERC20 token.

For this reason the exchange stores:

```solidity
IERC20 private immutable i_token;
```

The token is assigned in the constructor:

```solidity
constructor(address _tokenAddress) {
    if (_tokenAddress == address(0)) {
        revert UniswapV1Exchange__ZeroAddress();
    }

    i_token = IERC20(_tokenAddress);
}
```

The token is immutable because:
- it never changes after deployment
- immutable variables are cheaper than storage variables
- each Uniswap V1 exchange permanently supports one token pair

---

# Exact Input vs Exact Output Swaps

Uniswap V1 supports two swap modes.

---

## Exact Input Swap

The user specifies the exact amount of input asset.

Example:

```text
I want to sell exactly 1 ETH.
How many tokens do I receive?
```

The protocol calculates the output amount.

---

## Exact Output Swap

The user specifies the exact amount of output asset.

Example:

```text
I want to buy exactly 100 tokens.
How much ETH do I need?
```

The protocol calculates the required input amount.

---

# ETH → Token Swap Architecture

The ETH → Token swap flow is divided into:
- pricing functions
- internal swap execution functions
- external user-facing functions

This keeps the implementation modular and easier to understand.

---

# ETH → Token Input Swap Flow

Exact input swaps use:

```solidity
ethToTokenSwapInput()
ethToTokenTransferInput()
```

Both functions reuse:

```solidity
_ethToTokenInput()
```

which internally uses:

```solidity
_getInputPrice()
```

Flow:

```text
ethToTokenSwapInput()
        |
        | OR
        |
ethToTokenTransferInput()
        |
        v
_ethToTokenInput()
        |
        v
_getInputPrice()
```

---

# ETH → Token Output Swap Flow

Exact output swaps use:

```solidity
ethToTokenSwapOutput()
ethToTokenTransferOutput()
```

Both functions reuse:

```solidity
_ethToTokenOutput()
```

which internally uses:

```solidity
_getOutputPrice()
```

Flow:

```text
ethToTokenSwapOutput()
        |
        | OR
        |
ethToTokenTransferOutput()
        |
        v
_ethToTokenOutput()
        |
        v
_getOutputPrice()
```

---

# Why The Implementation Is Incremental

The functions are implemented incrementally:

```text
pricing functions
        ↓
quote functions
        ↓
internal swap execution
        ↓
external user-facing functions
```

This architecture mirrors the original Uniswap V1 implementation and helps isolate:
- pricing logic
- reserve accounting
- swap execution
- user interaction