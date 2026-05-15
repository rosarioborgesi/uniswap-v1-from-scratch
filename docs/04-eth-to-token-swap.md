# ETH to Token Swap

In this first version we focus only on the core AMM logic:

```text
ETH → ERC20 token
```

We ignore for now:
- factory
- liquidity providing
- LP tokens
- token to ETH swaps
- token to token swaps

The goal is to build the smallest working version of the exchange.

---

# Final Structure

To perform an ETH to token swap we need these functions:

```text
ethToTokenSwapInput()
_ethToTokenInput()
getEthToTokenInputPrice()
_getInputPrice()
tokenAddress()
```

---

# 1. tokenAddress()

```solidity
function tokenAddress() external view returns (address)
```

This returns the ERC20 token traded by the exchange.

Each exchange is linked to one token.

Example:

```text
ETH <-> DAI
ETH <-> USDC
ETH <-> WETH
```

---

# 2. _getInputPrice()

The `_getInputPrice()` function calculates how much output asset the user receives for a given input amount.

```solidity
function _getInputPrice(
    uint256 _inputAmount,
    uint256 _inputReserve,
    uint256 _outputReserve
) private pure returns (uint256)
```

The formula includes the Uniswap V1 fee:

```text
0.3% fee
997 / 1000 input used for pricing
```

## Deriving `_getInputPrice`

The swap is based on the constant product formula:

$$
x \cdot y = k
$$

where:
- `x` = input reserve
- `y` = output reserve
- `k` = constant product

In our Solidity function:

```solidity
function _getInputPrice(
    uint256 _inputAmount,
    uint256 _inputReserve,
    uint256 _outputReserve
) private pure returns (uint256)
```

the variables correspond to:

- `_inputAmount` = `Δx`
- `_inputReserve` = `x`
- `_outputReserve` = `y`
- return value = `Δy`

When a user swaps an input amount `Δx`, the input reserve increases and the output reserve decreases:

$$
(x + \Delta x)(y - \Delta y) = k
$$

Since:

$$
k = x \cdot y
$$

we can write:

$$
(x + \Delta x)(y - \Delta y) = x \cdot y
$$

Solving for `Δy`:

$$
\Delta y = y - \frac{x \cdot y}{x + \Delta x}
$$

This simplifies to:

$$
\Delta y = \frac{y \cdot \Delta x}{x + \Delta x}
$$

So the output amount is:

```text
output = outputReserve * inputAmount / (inputReserve + inputAmount)
```

---

## Adding the Fee

Uniswap V1 charges a 0.3% fee.

So only 99.7% of the input amount is used for pricing:

$$
\Delta x_{fee} = \Delta x \cdot \frac{997}{1000}
$$

To avoid decimals in Solidity, we keep the calculation scaled by `1000`.

If we replace $\Delta x$ with $\Delta x_{fee}$ inside the formula, we get:

$$
\Delta y =
\frac{
y \cdot (\Delta x \cdot 997)
}{
(x \cdot 1000) + (\Delta x \cdot 997)
}
$$

In Solidity:

```solidity
uint256 inputAmountWithFee = _inputAmount * 997;
uint256 numerator = inputAmountWithFee * _outputReserve;
uint256 denominator = (_inputReserve * 1000) + inputAmountWithFee;

return numerator / denominator;
```

This returns the amount of output tokens the user receives for a given input amount.

Integer division rounds down, which is expected in Solidity.

---

## Testing `_getInputPrice`

The pricing formula is the mathematical core of the AMM.

For this reason we test it separately before implementing the full swap flow.

The tests cover:
- correctness of the pricing formula
- invalid inputs
- invalid reserve states
- fuzz testing

---

### Revert Tests

The function should revert if:
- the input amount is zero
- one of the reserves is zero

Example:

```solidity
if (_inputAmount == 0) {
    revert UniswapV1Exchange__InsufficientInputAmount();
}

if (_inputReserve == 0 || _outputReserve == 0) {
    revert UniswapV1Exchange__InsufficientReserves();
}
```

A reserve cannot be zero because the AMM invariant:

$$
x \cdot y = k
$$

would break.

If one reserve becomes zero:
- the pool cannot quote prices correctly
- the pool cannot output assets anymore
- the constant product model becomes invalid

---

### Fuzz Testing

We also add a fuzz test for the pricing formula.

```solidity
function testGetInputPriceAlwaysMatchesAmmFormula(
    uint256 _inputAmount,
    uint256 _inputReserve,
    uint256 _outputReserve
)
```

Instead of testing only one example, fuzz testing automatically checks many combinations of:
- input amounts
- input reserves
- output reserves

The test verifies that the Solidity implementation always matches the mathematical formula.

---

### Why We Bound The Inputs

In the fuzz test we use:

```solidity
_inputAmount = bound(_inputAmount, 1, type(uint112).max);
_inputReserve = bound(_inputReserve, 1, type(uint112).max);
_outputReserve = bound(_outputReserve, 1, type(uint112).max);
```

The goal is:
- avoid meaningless overflow scenarios
- keep the test realistic
- simulate realistic AMM reserve sizes

The contract itself uses `uint256`.

The `uint112` bound is only a fuzz testing constraint.

---

### Why `uint112`?

In Uniswap V1 reserves are not stored in dedicated state variables.

The protocol directly uses:
- `address(this).balance`
- `token.balanceOf(address(this))`

However, in Uniswap V2 reserves are stored as:

```solidity
uint112 reserve0;
uint112 reserve1;
```

This was done for storage packing and gas optimization.

A small grammar improvement:

Using `uint112` in the fuzz tests mirrors realistic reserve sizes used by real AMMs and avoids overflow errors.

---

### Uniswap V2 Equivalent

The equivalent pricing function in Uniswap V2 is:

```solidity
getAmountOut(
    uint amountIn,
    uint reserveIn,
    uint reserveOut
)
```

The implementation is almost identical, the main difference is architectural:
- Uniswap V1 places the pricing logic inside the exchange contract
- Uniswap V2 places the pricing logic inside [`UniswapV2Library`]((https://github.com/Uniswap/v2-periphery/blob/master/contracts/libraries/UniswapV2Library.sol))

---

### How Uniswap V1 and V2 Test the Formula

Uniswap V1 and V2 mainly test swaps through integration tests:
- adding liquidity
- performing swaps
- checking balances
- checking events

The official tests mostly use fixed examples instead of fuzz testing.

In this project, we also test the pricing formula directly using fuzz tests.

Our fuzz test validates the pricing formula against many randomized reserve and input combinations automatically.

This gives higher confidence in the correctness of the AMM math and helps detect edge cases.

--- 

# 3. getEthToTokenInputPrice()

```solidity
function getEthToTokenInputPrice(uint256 _ethSold) external view returns (uint256)
```

This is the public quote function.

It tells the user how many tokens they would receive for a given ETH input.

It does not perform the swap.

It only reads:
- ETH reserve
- token reserve

Then it calls `_getInputPrice()`.

---

# 4. _ethToTokenInput()

```solidity
function _ethToTokenInput(
    uint256 _ethSold,
    uint256 _minTokens,
    uint256 _deadline,
    address _buyer,
    address _recipient
) private returns (uint256 tokensBought)
```

This is the internal swap function.

It performs the real swap logic:

```text
1. check deadline
2. check input values
3. read token reserve
4. calculate ETH reserve before the swap
5. calculate tokens bought
6. check slippage
7. transfer tokens to recipient
8. emit event
```

The ETH reserve must be calculated as:

```solidity
address(this).balance - _ethSold
```

because `msg.value` is already included in the contract balance when the function runs.

The function receives both:
- `_buyer`
- `_recipient`

because the buyer pays ETH, but the tokens can be sent to another address.

---

# 5. ethToTokenSwapInput()

```solidity
function ethToTokenSwapInput(
    uint256 _minTokens,
    uint256 _deadline
) external payable returns (uint256 tokensBought)
```

This is the public function called by the user.

The user sends ETH with `msg.value`.

The function calls `_ethToTokenInput()` using:

```solidity
_buyer = msg.sender
_recipient = msg.sender
```

So in this first version, the user who pays ETH also receives the tokens.

---

# Execution Flow

```text
User calls ethToTokenSwapInput()
        |
        v
ethToTokenSwapInput()
        |
        v
_ethToTokenInput()
        |
        v
_getInputPrice()
        |
        v
transfer tokens to recipient
```

---

# Why This Order?

We build the functions in this order:

```text
1. tokenAddress()
2. _getInputPrice()
3. getEthToTokenInputPrice()
4. _ethToTokenInput()
5. ethToTokenSwapInput()
```

Reason:

```text
tokenAddress()
→ confirms the exchange token

_getInputPrice()
→ implements the AMM math

getEthToTokenInputPrice()
→ exposes price quotes

_ethToTokenInput()
→ implements the swap logic

ethToTokenSwapInput()
→ exposes the swap to users
```

This keeps the implementation simple and incremental.

---

# First Test Goal

For the first test, we manually seed the exchange with reserves:

```text
10 ETH
1,000 tokens
```

Then a user swaps:

```text
1 ETH
```

The test should check that:
- the user receives tokens
- the exchange receives ETH
- the exchange token reserve decreases
- the output matches `getEthToTokenInputPrice()`

For now, liquidity is added manually in the test.

We will implement proper liquidity providing later.