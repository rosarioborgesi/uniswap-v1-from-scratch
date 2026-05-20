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

# tokenAddress()

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

# ETH → Token Input Swap Flow

For the ETH → token exact input flow, users can call:

```solidity
ethToTokenSwapInput()
```

or:

```solidity
ethToTokenTransferInput()
```

The difference is:

```text
ethToTokenSwapInput()
→ buyer receives tokens

ethToTokenTransferInput()
→ another recipient receives tokens
```

Both functions reuse the same internal swap logic:

```text
User calls ethToTokenSwapInput()
        |
        | OR
        |
User calls ethToTokenTransferInput()
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

## Why We Build The Functions In This Order

We implemented the functions incrementally:

```text
1. _getInputPrice()
2. getEthToTokenInputPrice()
3. _ethToTokenInput()
4. ethToTokenSwapInput()
5. ethToTokenTransferInput()
```

Reason:

```text
_getInputPrice()
→ implements the AMM pricing math

getEthToTokenInputPrice()
→ exposes public price quotes

_ethToTokenInput()
→ implements the core swap logic

ethToTokenSwapInput()
→ user swaps ETH for tokens

ethToTokenTransferInput()
→ user swaps ETH and sends tokens to another address
```

This mirrors the architecture of the original Uniswap V1 implementation and keeps the implementation modular and incremental.

---

# _getInputPrice()

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

The swap is based on the constant product invariant:

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

```text
Δx = input amount   -> `_inputAmount`
x  = input reserve  -> `_inputReserve`
y  = output reserve -> `_outputReserve`
Δy = output amount  -> return value
```

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

Implementation:

```solidity
uint256 inputAmountWithFee = _inputAmount * 997;

uint256 numerator =
    inputAmountWithFee * _outputReserve;

uint256 denominator =
    (_inputReserve * 1000) + inputAmountWithFee;

return numerator / denominator;
```

This returns the amount of output tokens the user receives for a given input amount.

---

### Integer Division

Solidity integer division rounds down.

This slightly favors the liquidity pool and preserves the invariant safely.

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
- Uniswap V1 places the pricing logic inside the exchange contract [uniswap_exchange.py](https://github.com/Uniswap/v1-contracts/blob/master/contracts/uniswap_exchange.vy)
- Uniswap V2 places the pricing logic inside [`UniswapV2Library`](https://github.com/Uniswap/v2-periphery/blob/master/contracts/libraries/UniswapV2Library.sol)

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

# getEthToTokenInputPrice()

```solidity
function getEthToTokenInputPrice(uint256 _ethSold) external view returns (uint256)
```

This is the public quote function.

It tells the user how many tokens they would receive for a given ETH input.

It does not perform the swap.

The function:
- reads the ETH reserve from `address(this).balance`
- reads the token reserve from `token.balanceOf(address(this))`
- calls `_getInputPrice()`

---

# _ethToTokenInput()

```solidity
function _ethToTokenInput(
    uint256 _ethSold,
    uint256 _minTokens,
    uint256 _deadline,
    address _buyer,
    address _recipient
) private returns (uint256 tokensBought)
```

This is the internal swap execution function.

It performs the actual ETH → token swap.


---

## Why We Use `address(this).balance - _ethSold`

Inside the function, `msg.value` has already been added to the contract balance.

So:

```solidity
address(this).balance
```

already includes the ETH sent by the user.

To calculate the reserve before the swap, we subtract the ETH input:

```solidity
uint256 ethReserveBeforeSwap = address(this).balance - _ethSold;
```

This mirrors the original Uniswap V1 implementation.

---

## Slippage Protection

The user provides:

```solidity
_minTokens
```

which represents the minimum acceptable output amount.

If the calculated output is lower:

```solidity
tokensBought < _minTokens
```

the transaction reverts.

This protects users from excessive price movement or front-running.

---

## Buyer vs Recipient

The function receives both:
- `_buyer`
- `_recipient`

because the address paying ETH is not necessarily the address receiving the tokens.

In the basic swap flow:
- buyer = msg.sender
- recipient = msg.sender

But more advanced flows may separate them.

---

# ethToTokenSwapInput()

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


<!-- # Integration test

The test file that tests ETH → ERC20 token swap in the original Uniswap V1 contract is [`test_eth_to_token.py`](https://github.com/Uniswap/v1-contracts/blob/master/tests/exchange/test_token_to_token.py) -->


# receive Function

When a user sends ETH directly to the contract, the `receive` function is triggered.

The function internally calls `_ethToTokenInput()`.

In this case, the user cannot specify:
- the minimum amount of tokens bought (`1`)
- the deadline (`block.timestamp`)

This mirrors the original Uniswap V1 behavior and allows users to swap ETH for tokens by simply sending ETH to the exchange contract.


# `ethToTokenTransferInput()`

```solidity
function ethToTokenTransferInput(
    uint256 _minTokens,
    uint256 _deadline,
    address _recipient
) public payable returns (uint256)
```

This function performs an ETH → token swap and sends the output tokens to another address.

Unlike:

```solidity
ethToTokenSwapInput()
```

where:
- buyer = recipient

this function allows:

```text
buyer != recipient
```

This is useful for:
- payments
- smart contract integrations
- sending swapped tokens directly to another user

---

The original Uniswap V1 implementation checks that the recipient is valid.

The recipient:
- cannot be the exchange contract itself
- cannot be the zero address

The function reuses the internal:

```solidity
_ethToTokenInput()
```

# `_getOutputPrice`

The `_getOutputPrice()` function is used for exact output swaps.

With `_getInputPrice()`, the user says:

```text
I want to sell exactly this amount of input.
```

With `_getOutputPrice()`, the user says:

```text
I want to buy exactly this amount of output.
```

So the function calculates how much input asset is required.

---

## Difference From `_getInputPrice`

```text
_getInputPrice()
→ exact input
→ calculate output

_getOutputPrice()
→ exact output
→ calculate required input
```

Example:

```text
_getInputPrice():
I sell 1 ETH. How many tokens do I get?

_getOutputPrice():
I want 100 tokens. How much ETH do I need?
```

# ETH → Token Output Swap Flow

For the ETH → token exact output flow, users can call:

```solidity
ethToTokenSwapOutput()
```

or:

```solidity
ethToTokenTransferOutput()
```

The difference is:

```text
ethToTokenSwapOutput()
→ buyer receives tokens

ethToTokenTransferOutput()
→ another recipient receives tokens
```

Both functions reuse the same internal swap logic:

```text
User calls ethToTokenSwapOutput()
        |
        | OR
        |
User calls ethToTokenTransferOutput()
        |
        v
_ethToTokenOutput()
        |
        v
_getOutputPrice()
        |
        v
refund unused ETH
        |
        v
transfer tokens to recipient
```

---

## Why We Build The Functions In This Order

We implemented the functions incrementally:

```text
1. _getOutputPrice()
2. getEthToTokenOutputPrice()
3. _ethToTokenOutput()
4. ethToTokenSwapOutput()
5. ethToTokenTransferOutput()
```

Reason:

```text
_getOutputPrice()
→ implements the exact output AMM math

getEthToTokenOutputPrice()
→ exposes public price quotes

_ethToTokenOutput()
→ implements the core exact output swap logic

ethToTokenSwapOutput()
→ user buys an exact amount of tokens

ethToTokenTransferOutput()
→ user buys tokens and sends them to another address
```

Unlike exact input swaps:

```text
user specifies ETH input
→ protocol calculates token output
```

exact output swaps work as:

```text
user specifies token output
→ protocol calculates required ETH input
```

This mirrors the architecture of the original Uniswap V1 implementation and keeps the implementation modular and incremental.


---

# `_getOutputPrice`

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

Mapping to Solidity:

```solidity
function _getOutputPrice(
    uint256 _outputAmount,
    uint256 _inputReserve,
    uint256 _outputReserve
) private pure returns (uint256) {
    uint256 numerator =
        _inputReserve * _outputAmount * 1000;

    uint256 denominator =
        (_outputReserve - _outputAmount) * 997;

    return numerator / denominator + 1;
}
```

where

```text
Δx = required input amount  -> return value
x  = input reserve          -> `_inputReserve`
y  = output reserve         -> `_outputReserve`
Δy = desired output amount  -> `_outputAmount`
```

---

### Why We Add `+ 1`

Solidity integer division rounds down.

Without `+1`, the trader could pay slightly less than required while still receiving the exact output amount.

Adding `+1` guarantees the pool receives enough input tokens to preserve the invariant.

---

## When It Is Used

For the ETH → token flow, `_getOutputPrice()` is used by:

```text
getEthToTokenOutputPrice()
ethToTokenSwapOutput()
ethToTokenTransferOutput()
```

These functions are the exact output versions of the ETH → token swap.

---

# `_ethToTokenOutput()`

```solidity
function _ethToTokenOutput(
    uint256 _tokensBought,
    uint256 _maxEth,
    uint256 _deadline,
    address _buyer,
    address _recipient
) private returns (uint256)
```

This is the internal exact output swap function.

Unlike `_ethToTokenInput()`:

```text
user specifies exact ETH input
→ protocol calculates token output
```

here:

```text
user specifies exact token output
→ protocol calculates required ETH input
```

---

## Parameters

```text
_tokensBought
→ exact amount of tokens the user wants

_maxEth
→ maximum ETH the user is willing to spend

_deadline
→ transaction expiration timestamp

_buyer
→ address paying ETH

_recipient
→ address receiving tokens
```

---

## Execution Flow

The function performs:

```text
1. check deadline
2. validate inputs
3. read reserves
4. calculate ETH reserve before swap
5. calculate required ETH input
6. check slippage protection
7. refund unused ETH
8. transfer tokens
9. emit event
```

---

## ETH Reserve Before Swap

```solidity
// msg.value is already included in address(this).balance.
// Since _maxEth = msg.value, subtracting _maxEth gives the ETH reserve
// before the swap and can never underflow.
uint256 ethReserve = address(this).balance - _maxEth;
```

When the function executes:
- `msg.value` has already been added to the contract balance
- `_maxEth = msg.value`

So subtracting `_maxEth` reconstructs the ETH reserve before the swap.

---

## Calculating Required ETH

The required ETH amount is calculated with:

```solidity
uint256 ethSold =
    _getOutputPrice(
        _tokensBought,
        ethReserve,
        tokenReserve
    );
```

Unlike `_getInputPrice()`:
- the user chooses the output amount
- the protocol calculates the required input amount

---

## Liquidity Constraint

`_getOutputPrice()` requires:

```text
_tokensBought < tokenReserve
```

otherwise the AMM invariant would break.

This guarantees the exchange can never send more tokens than it owns.

---

## Slippage Protection

```solidity
if (ethSold > _maxEth) {
    revert UniswapV1Exchange__EthSoldExceedsMaxEth();
}
```

This is the slippage protection for exact output swaps.

Meaning:

```text
"I want exactly these tokens,
but I refuse to spend more than this amount of ETH."
```

If the required ETH exceeds `_maxEth`, the transaction reverts.

---

## ETH Refund

If the user sends more ETH than required:

```solidity
uint256 ethRefund = _maxEth - ethSold;
```

the remaining ETH is refunded to the buyer.

This mirrors the original Uniswap V1 implementation.

---

# `ethToTokenSwapOutput()`

```solidity
function ethToTokenSwapOutput(
    uint256 _tokensBought,
    uint256 _deadline
) public payable returns (uint256)
```

This is the public exact output swap function.

Unlike `ethToTokenSwapInput()`:

```text
user specifies exact ETH input
→ protocol calculates token output
```

here:

```text
user specifies exact token output
→ protocol calculates required ETH input
```

The user sends ETH with `msg.value`.

In this flow:
- `_tokensBought` is the exact amount of tokens the user wants
- `msg.value` is the maximum ETH the user is willing to spend
- unused ETH is refunded

The function internally calls:

```solidity
_ethToTokenOutput(
    _tokensBought,
    msg.value,
    _deadline,
    msg.sender,
    msg.sender
)
```

So in this version:
- buyer = recipient

The exact output swap flow becomes:

```text
User calls ethToTokenSwapOutput()
        |
        v
_ethToTokenOutput()
        |
        v
_getOutputPrice()
        |
        v
refund unused ETH
        |
        v
transfer tokens to user
```
---


