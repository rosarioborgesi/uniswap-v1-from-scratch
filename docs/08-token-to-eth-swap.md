# Token to ETH Swap

So far our exchange supports:

```text
ETH → Token swaps
```

Now we implement the opposite direction:

```text
Token → ETH swaps
```

This allows users to sell ERC20 tokens to the exchange and receive ETH in return.

---

# Swap direction

In an ETH to token swap, the user sends ETH and receives tokens.

In a token to ETH swap, the user sends tokens and receives ETH.

```text
User sells ERC20 tokens
        ↓
Exchange sends ETH to user
```

The AMM formula is the same.

The only thing that changes is which reserve is the input reserve and which reserve is the output reserve.

---

# Reserves

For a token to ETH swap:

```text
Input asset  = ERC20 token
Output asset = ETH
```

So:

```solidity
uint256 inputReserve = tokenReserve;
uint256 outputReserve = ethReserve;
```

The token reserve is read with:

```solidity
uint256 tokenReserve = i_token.balanceOf(address(this));
```

The ETH reserve is read with:

```solidity
uint256 ethReserve = address(this).balance;
```

---

# Pricing formula

We reuse the same internal pricing function used for ETH to token swaps:

```solidity
_getInputPrice(
    _inputAmount,
    _inputReserve,
    _outputReserve
)
```

For token to ETH swaps:

```solidity
uint256 ethBought = _getInputPrice(
    _tokensSold,
    tokenReserve,
    ethReserve
);
```

Where:

- `_tokensSold` = amount of tokens sold by the user
- `tokenReserve` = current token reserve
- `ethReserve` = current ETH reserve
- `ethBought` = amount of ETH received by the user

The formula is:

$$
\Delta y =
\frac{
\Delta x \cdot 997 \cdot y
}{
x \cdot 1000 + \Delta x \cdot 997
}
$$

Where:

- $\Delta x$ = tokens sold
- $x$ = token reserve
- $y$ = ETH reserve
- $\Delta y$ = ETH bought

The `997 / 1000` factor applies the 0.3% swap fee.

---

# tokenToEthSwapInput

The external user-facing function will be:

```solidity
function tokenToEthSwapInput(
    uint256 _tokensSold,
    uint256 _minEth,
    uint256 _deadline
)
    external
    returns (uint256 ethBought)
```

Parameters:

- `_tokensSold` → amount of tokens the user sells
- `_minEth` → minimum ETH the user is willing to receive
- `_deadline` → timestamp after which the transaction becomes invalid

The function returns:

```text
ETH bought
```

---

# Slippage protection

The user specifies:

```solidity
_minEth
```

This protects the user from receiving less ETH than expected.

If the calculated ETH output is lower than `_minEth`, the transaction reverts.

```solidity
if (ethBought < _minEth) {
    revert UniswapV1Exchange__InsufficientOutputAmount();
}
```

---

# Deadline protection

The user also specifies:

```solidity
_deadline
```

The transaction is valid only if:

```solidity
_deadline > block.timestamp
```

If the deadline has expired, the transaction reverts.

```solidity
if (_deadline <= block.timestamp) {
    revert UniswapV1Exchange__DeadlineExpired();
}
```

This prevents old transactions from being executed later under different market conditions.

---

# Swap flow

The token to ETH swap flow is:

```text
Validate deadline
        ↓
Validate input amount
        ↓
Read token reserve
        ↓
Read ETH reserve
        ↓
Calculate ETH bought
        ↓
Validate minimum ETH output
        ↓
Transfer tokens from user to exchange
        ↓
Send ETH to user
```

---

# Important ordering

For token to ETH swaps, the exchange first calculates the output amount using the current reserves.

Then it transfers tokens from the user and sends ETH to the user.

The user must approve the exchange before calling the function:

```solidity
i_token.approve(address(exchange), tokensSold);
```

Then the exchange can pull the tokens with:

```solidity
i_token.transferFrom(msg.sender, address(this), _tokensSold);
```

Finally the exchange sends ETH to the user:

```solidity
(bool success,) = msg.sender.call{value: ethBought}("");
```

---

# Example

Suppose the pool contains:

```text
10 ETH
20,000 DAI
```

A user sells:

```text
1,000 DAI
```

For this swap:

```text
input reserve  = 20,000 DAI
output reserve = 10 ETH
```

The function calculates the amount of ETH bought using:

```solidity
_getInputPrice(
    1000 ether,
    20_000 ether,
    10 ether
);
```

The user receives ETH, and the pool reserves become:

```text
ETH reserve decreases
Token reserve increases
```

---

# Reserve updates

After the swap:

```text
Token reserve increases by tokens sold
ETH reserve decreases by ETH bought
```

So the pool moves from:

```text
ETH reserve   = x
Token reserve = y
```

to:

```text
ETH reserve   = x - ethBought
Token reserve = y + tokensSold
```

The constant product invariant is preserved after applying the swap fee.

---

# Token -> ETH Input Swap flow

For the Token → ETH input swap we follow the same structure used for the ETH → Token input swap.

The external user-facing functions are:

```solidity
tokenToEthSwapInput()
tokenToEthTransferInput()
```

These are the function called directly by the user.

The user provides:

```text
tokens sold
minimum ETH accepted
deadline
```

The external functions performs the high-level validations and then delegates the swap logic to the internal function:

```solidity
_tokenToEthInput()
```

The internal function is responsible for:

```text
reading reserves
calculating ETH output
checking slippage
transferring tokens from the user
sending ETH to the recipient
```

To calculate the ETH output, we also expose a pricing function:

```solidity
getTokenToEthInputPrice()
```

This function receives the amount of tokens sold and returns the amount of ETH that would be bought.

Internally it reuses the same `_getInputPrice()` formula already used for ETH → Token swaps.

The only difference is the reserve order:

```solidity
_getInputPrice(
    tokensSold,
    tokenReserve,
    ethReserve
);
```

So the call flow becomes:

```text
tokenToEthSwapInput()  or tokenToEthTransferInput()
        ↓
_tokenToEthInput()
        ↓
getTokenToEthInputPrice()
        ↓
_getInputPrice()
```

Where:

- `tokenToEthSwapInput()` is the external entry point
- `_tokenToEthInput()` executes the swap
- `getTokenToEthInputPrice()` calculates the ETH output
- `_getInputPrice()` applies the constant product formula with the 0.3% fee

This keeps the contract structure consistent with the ETH → Token swap implementation and lets us reuse the same AMM pricing logic.

The implementation order will be:

1. getTokenToEthInputPrice()
2. _tokenToEthInput()
3. tokenToEthSwapInput()
4. tokenToEthTransferInput()

# _getInputPrice()

We have already implemented this function. Check [04-eth-to-token-swap.md](./04-eth-to-token-swap.md).

# getTokenToEthInputPrice()

Internally, `getTokenToEthInputPrice()` reuses the `_getInputPrice()` function that we already implemented for ETH → Token swaps.

The AMM pricing logic remains exactly the same.

The only difference is the reserve order:

```solidity
_getInputPrice(
    tokensSold,
    tokenReserve,
    ethReserve
);
```

