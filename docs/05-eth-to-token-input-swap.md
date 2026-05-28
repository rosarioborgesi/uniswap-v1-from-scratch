# ETH → Token Input Swap

In an exact input swap:
- the user specifies the exact ETH input
- the protocol calculates the token output

Example:

```text
Sell exactly 1 ETH
Receive as many tokens as possible
```

---

# ETH → Token Input Swap Flow

The user-facing functions are:

```solidity
ethToTokenSwapInput()
ethToTokenTransferInput()
```

Both functions reuse:

```solidity
_ethToTokenInput()
```

which internally calls:

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

# Function Architecture

The implementation order is:

```text
1. _getInputPrice()
2. getEthToTokenInputPrice()
3. _ethToTokenInput()
4. ethToTokenSwapInput()
5. ethToTokenTransferInput()
```

This keeps the pricing logic separated from the swap execution logic.

---

# `_getInputPrice()`

The pricing formula is based on:

$$
x \cdot y = k
$$

where:
- `x` = input reserve
- `y` = output reserve

The user specifies:
- exact input amount `Δx`

The protocol calculates:
- output amount `Δy`

Without fees:

$$
\Delta y =
\frac{
y \cdot \Delta x
}{
x + \Delta x
}
$$

---

## Swap Fee

Uniswap V1 charges a 0.3% fee.

Only:

$$
99.7\%
$$

of the input amount contributes to pricing.

---

## Deriving `_getInputPrice`

The swap is based on the constant product invariant:

$$
x \cdot y = k
$$

where:
- `x` = input reserve
- `y` = output reserve
- `k` = constant product

In the exact input case:
- the user specifies the exact input amount `Δx`
- the protocol calculates the output amount `Δy`

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

Factoring `Δy`:

$$
\Delta y (x + \Delta x) = y\Delta x
$$

Solving for `Δy`:

$$
\Delta y =
\frac{
y \cdot \Delta x
}{
x + \Delta x
}
$$

So the output amount becomes:

```text
output = outputReserve * inputAmount / (inputReserve + inputAmount)
```

---

### Adding the Fee

Uniswap V1 charges a 0.3% fee.

So only 99.7% of the input amount contributes to pricing:

$$
\Delta x_{fee} =
\Delta x \cdot \frac{997}{1000}
$$

To avoid decimals in Solidity, the calculation is scaled by `1000`.

Replacing `Δx` with `Δx_fee` gives:

$$
\Delta y =
\frac{
y \cdot (\Delta x \cdot 997)
}{
(x \cdot 1000) + (\Delta x \cdot 997)
}
$$


### Mapping to Solidity

```solidity
function _getInputPrice(
    uint256 _inputAmount,
    uint256 _inputReserve,
    uint256 _outputReserve
) private pure returns (uint256) {
        
    uint256 inputAmountWithFee = _inputAmount * 997;
    uint256 numerator = inputAmountWithFee * _outputReserve;
    uint256 denominator = (_inputReserve * 1000) + inputAmountWithFee;
    return numerator / denominator;
}
```

where:

```text
Δx = input amount   -> `_inputAmount`
x  = input reserve  -> `_inputReserve`
y  = output reserve -> `_outputReserve`
Δy = output amount  -> return value
```

---

# `getEthToTokenInputPrice()`

```solidity
function getEthToTokenInputPrice(uint256 _ethSold)
```

This is the public quote function.

It returns how many tokens would be received for a given ETH input.

It does not execute the swap.

---

# `_ethToTokenInput()`

```solidity
function _ethToTokenInput(...)
```

This is the internal swap execution function.

Responsibilities:
- validate inputs
- read reserves
- calculate token output
- check slippage protection
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

So the reserve before the swap is reconstructed with:

```solidity
uint256 ethReserve = address(this).balance - _ethSold;
```

---

## Slippage Protection

The user specifies:

```solidity
_minTokens
```

If:

```solidity
tokensBought < _minTokens
```

the transaction reverts.

This protects users from excessive price movement and front-running.

---

# `ethToTokenSwapInput()`

```solidity
function ethToTokenSwapInput(...)
```

The caller:
- sends ETH
- receives tokens directly

Internally:

```text
buyer = msg.sender
recipient = msg.sender
```

---

# `ethToTokenTransferInput()`

```solidity
function ethToTokenTransferInput(...)
```

The caller:
- sends ETH
- another address receives the tokens

Internally:

```text
buyer = msg.sender
recipient = _recipient
```

This is useful for:
- payments
- integrations
- smart contracts

---

# receive Function

The contract also supports direct ETH transfers through:

```solidity
receive()
```

Sending ETH directly to the exchange automatically performs an ETH → Token swap.

This mirrors the original Uniswap V1 behavior.