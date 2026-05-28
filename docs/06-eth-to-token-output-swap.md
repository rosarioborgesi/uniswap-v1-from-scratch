# ETH → Token Output Swap

In an exact output swap:
- the user specifies the exact token output
- the protocol calculates the required ETH input

Example:

```text
Buy exactly 100 tokens
Spend as little ETH as necessary
```

---

# ETH → Token Output Swap Flow

The user-facing functions are:

```solidity
ethToTokenSwapOutput()
ethToTokenTransferOutput()
```

Both functions reuse:

```solidity
_ethToTokenOutput()
```

which internally calls:

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

# Function Architecture

The implementation order is:

```text
1. _getOutputPrice()
2. getEthToTokenOutputPrice()
3. _ethToTokenOutput()
4. ethToTokenSwapOutput()
5. ethToTokenTransferOutput()
```

---

# `_getOutputPrice()`

The swap is still based on:

$$
x \cdot y = k
$$

But now:
- the user specifies exact output `Δy`
- the protocol calculates required input `Δx`

Without fees:

$$
\Delta x =
\frac{
x \cdot \Delta y
}{
y - \Delta y
}
$$

---

## Swap Fee

Including the 0.3% fee:

$$
\Delta x =
\frac{
x \cdot \Delta y \cdot 1000
}{
(y - \Delta y) \cdot 997
}
$$

---

## Deriving `_getOutputPrice`

The swap is still based on the constant product invariant:

$$
x \cdot y = k
$$

where:
- `x` = input reserve
- `y` = output reserve

In the exact output case:
- the user specifies the exact output amount `Δy`
- the protocol calculates the required input amount `Δx`

After the swap:
- the input reserve increases
- the output reserve decreases

So:

$$
(x + \Delta x)(y - \Delta y) = x \cdot y
$$

Expanding:

$$
xy - x\Delta y + y\Delta x - \Delta x \Delta y = xy
$$

Canceling `xy` on both sides:

$$
-x\Delta y + y\Delta x - \Delta x\Delta y = 0
$$

Factoring `Δx`:

$$
\Delta x (y - \Delta y) = x\Delta y
$$

Solving for `Δx`:

$$
\Delta x =
\frac{
x \cdot \Delta y
}{
y - \Delta y
}
$$

This is the exact output formula without fees.

---

### Adding the Fee

Uniswap V1 charges a 0.3% fee.

So only 99.7% of the input amount contributes to pricing:

$$
\Delta x_{fee} =
\Delta x \cdot \frac{997}{1000}
$$

Rearranging the formula with fees gives:

$$
\Delta x =
\frac{
x \cdot \Delta y \cdot 1000
}{
(y - \Delta y) \cdot 997
}
$$

### Mapping to Solidity

```solidity
function _getOutputPrice(
    uint256 _outputAmount,
    uint256 _inputReserve,
    uint256 _outputReserve
) private pure returns (uint256) {

    uint256 numerator = _inputReserve * _outputAmount * 1000;
    uint256 denominator = (_outputReserve - _outputAmount) * 997;
    return numerator / denominator + 1;
}
```

where:

```text
Δx = required input amount  -> return value
x  = input reserve          -> `_inputReserve`
y  = output reserve         -> `_outputReserve`
Δy = desired output amount  -> `_outputAmount`
```

### Why We Add `+1`

Solidity integer division rounds down.

Without:

```solidity
+1
```

the trader could slightly underpay.

Adding `+1` guarantees the pool receives enough input assets to preserve the invariant.

---

---

# `getEthToTokenOutputPrice()`

```solidity
function getEthToTokenOutputPrice(uint256 _tokensBought)
```

This is the public quote function.

It returns how much ETH is required to buy an exact amount of tokens.

---

# `_ethToTokenOutput()`

```solidity
function _ethToTokenOutput(...)
```

This is the internal exact output swap execution function.

Responsibilities:
- validate inputs
- calculate required ETH
- check slippage protection
- refund unused ETH
- transfer tokens
- emit events

---

## ETH Reserve Before Swap

Inside the function:

```solidity
address(this).balance
```

already includes:

```solidity
msg.value
```

Since:

```solidity
msg.value = _maxEth
```

the reserve before the swap is reconstructed with:

```solidity
uint256 ethReserve = address(this).balance - _maxEth;
```

---

## Slippage Protection

The user specifies:

```solidity
_maxEth
```

If:

```solidity
ethSold > _maxEth
```

the transaction reverts.

Meaning:

```text
I want exactly these tokens,
but I refuse to spend more than this amount of ETH.
```

---

## ETH Refund

If:

```solidity
_maxEth > ethSold
```

the remaining ETH is refunded to the buyer.

This mirrors the original Uniswap V1 implementation.

---

# `ethToTokenSwapOutput()`

```solidity
function ethToTokenSwapOutput(...)
```

The caller:
- specifies exact token output
- sends maximum ETH
- receives tokens directly

Unused ETH is refunded.

---

# `ethToTokenTransferOutput()`

```solidity
function ethToTokenTransferOutput(...)
```

The caller:
- pays ETH
- another address receives the tokens

Internally:

```text
buyer = msg.sender
recipient = _recipient
```

This is useful for:
- integrations
- smart contracts
- payments