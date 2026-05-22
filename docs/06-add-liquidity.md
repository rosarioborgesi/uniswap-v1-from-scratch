# Add Liquidity

Now we implement the function that allows users to provide liquidity to the pool.

A liquidity provider deposits:

```text
ETH + ERC20 tokens
```

into the exchange reserves.

In return, the protocol mints liquidity shares that represent ownership of the pool.

---

# The addLiquidity function

The core function is:

```solidity
function addLiquidity(uint256 _maxTokens)
    external
    payable
    returns (uint256 liquidity)
```

Parameters:

- `_maxTokens` → maximum amount of tokens the user is willing to deposit
- `msg.value` → ETH sent to the pool

The function returns:

```text
liquidity shares minted
```

---

# Two different cases

The logic changes depending on whether the pool is empty or already initialized.

## Case 1 — First liquidity provider

If the pool has no liquidity yet:

```solidity
if (totalLiquidity == 0)
```

then the first liquidity provider defines the initial market price.

Example:

```text
10 ETH + 20,000 DAI
```

defines:

$$
1\ \text{ETH} = 2000\ \text{DAI}
$$

At this stage:

- there is no existing ratio to preserve
- the user can choose any ratio
- the pool gets initialized

The contract simply:

1. accepts ETH
2. transfers tokens
3. mints initial liquidity shares

---

# Case 2 — Existing pool

Once liquidity already exists, new deposits must preserve the current reserve ratio.

Suppose the pool currently contains:

```text
10 ETH
20,000 DAI
```

The ratio is:

```text
1 ETH = 2000 DAI
```

If a user sends:

```text
1 ETH
```

they must also deposit:

```text
2000 DAI
```

otherwise the pool price would change.

---

# Computing the required token amount

The deposited token amount must be proportional to the existing reserves.

Formula:

$$
\text{tokenAmount} =
\frac{
\text{msg.value} \cdot \text{tokenReserve}
}{
\text{ethReserve}
}
$$

Where:

- `msg.value` = ETH being added
- `tokenReserve` = current token reserve
- `ethReserve` = current ETH reserve

---

# Important detail about ethReserve

Inside `addLiquidity`, the ETH sent with the current transaction is already included in:

```solidity
address(this).balance
```

So to obtain the previous ETH reserve we must subtract `msg.value`.

Example:

```solidity
uint256 ethReserve = address(this).balance - msg.value;
```

This is a very important detail in Uniswap V1.

---

# Liquidity shares

Liquidity shares must also be minted proportionally.

Formula:

$$
\text{liquidityMinted} =
\frac{
\text{msg.value} \cdot \text{totalLiquidity}
}{
\text{ethReserve}
}
$$

Where:

- `totalLiquidity` = total existing liquidity shares
- `ethReserve` = reserve before the deposit

This ensures that ownership percentages remain fair.

---

# Example

Current pool:

```text
10 ETH
20,000 DAI
100 liquidity shares
```

A user deposits:

```text
1 ETH
2000 DAI
```

Liquidity minted:

$$
\frac{1 \cdot 100}{10} = 10
$$

The user receives:

```text
10 liquidity shares
```

New total liquidity:

```text
110 shares
```

---

# Validations

We should also validate:

- ETH amount must be greater than zero
- token amount must not exceed `_maxTokens`
- token transfer must succeed

Example:

```solidity
if (msg.value == 0) {
    revert UniswapV1Exchange__InsufficientEthAmount();
}
```

---

# State we need to track

We will need:

```solidity
mapping(address => uint256) public liquidity;
```

to track each provider shares.

And:

```solidity
uint256 public totalLiquidity;
```

to track the total supply of liquidity shares.

---

# Flow summary

The add liquidity flow becomes:

```text
User sends ETH
        ↓
Calculate required tokens
        ↓
Transfer tokens to the pool
        ↓
Mint liquidity shares
        ↓
Update total liquidity
```

---

# LP Tokens in Uniswap V1

In Uniswap V1, liquidity shares are implemented as ERC20 tokens.

This means the exchange contract is not only an AMM exchange but also an ERC20 token contract representing ownership of the pool.

Liquidity providers receive LP tokens when they deposit liquidity.

Example:

```text
Alice deposits:
10 ETH + 20,000 DAI
```

and receives:

```text
100 UNI-V1 LP tokens
```

These LP tokens represent Alice's share of the pool and can later be redeemed to withdraw liquidity.

The original Uniswap V1 stores the standard ERC20 state variables directly inside the exchange contract:

```python
name: public(bytes32)
symbol: public(bytes32)
decimals: public(uint256)
totalSupply: public(uint256)
balances: uint256[address]
allowances: (uint256[address])[address]
```

This allows LP tokens to behave exactly like normal ERC20 tokens:

- transferable
- approvable
- usable in other protocols

In our Solidity implementation, instead of manually tracking liquidity shares with:

```solidity
mapping(address => uint256) private s_liquidity;
uint256 private s_totalLiquidity;
```

we can model LP shares by inheriting from OpenZeppelin ERC20:

```solidity
contract UniswapV1Exchange is ERC20
```

This allows us to mint LP tokens directly when liquidity is added:

```solidity
_mint(msg.sender, liquidityMinted);
```

and use:

```solidity
totalSupply()
```

to track the total liquidity in the pool.

---

# addLiquidity()

The `addLiquidity` function allows users to deposit ETH and tokens into the pool and receive LP tokens representing their share of the liquidity.

The function has two main execution paths:

```text
1. Pool already initialized
2. Pool empty (first liquidity provider)
```

Before handling these cases, the function performs several validations.

---

## Function signature

```solidity
function addLiquidity(
    uint256 _minLiquidity,
    uint256 _maxTokens,
    uint256 _deadline
)
    external
    payable
    returns (uint256)
```

Parameters:

- `_minLiquidity` → minimum amount of LP tokens the user is willing to receive
- `_maxTokens` → maximum amount of tokens the user is willing to deposit
- `_deadline` → timestamp after which the transaction becomes invalid

The function is:

```solidity
payable
```

because users deposit ETH through:

```solidity
msg.value
```

The function returns the amount of LP tokens minted.

---

## Deadline validation

```solidity
if (_deadline <= block.timestamp) {
    revert UniswapV1Exchange__DeadlineExpired();
}
```

The transaction is valid only if:

```solidity
_deadline > block.timestamp
```

This prevents old transactions from being executed later under different pool conditions.

---

## Token amount validation

```solidity
if (_maxTokens == 0) {
    revert UniswapV1Exchange__MaxTokensIsZero();
}
```

Liquidity providers must deposit tokens together with ETH.

A liquidity addition with zero tokens is invalid.

---

## ETH amount validation

```solidity
if (msg.value == 0) {
    revert UniswapV1Exchange__InsufficientEthAmount();
}
```

Liquidity providers must also send ETH.

---

## Reading total liquidity

```solidity
uint256 totalLiquidity = totalSupply();
```

The exchange contract inherits from ERC20 and LP shares are represented as ERC20 tokens.

Because of this:

```solidity
totalSupply()
```

represents the total amount of LP tokens currently minted.

This value tells us whether the pool already exists.

---

## Case 1 — Pool already initialized

```solidity
if (totalLiquidity > 0)
```

If liquidity already exists, new deposits must preserve the current reserve ratio.

---

## Minimum liquidity validation

```solidity
if (_minLiquidity == 0) {
    revert UniswapV1Exchange__MinLiquidityIsZero();
}
```

The user specifies the minimum amount of LP tokens they are willing to receive.

This acts as slippage protection.

---

## ETH reserve calculation

```solidity
uint256 ethReserve = address(this).balance - msg.value;
```

Inside a payable function:

```solidity
address(this).balance
```

already includes the ETH sent in the current transaction.

To obtain the reserve before the deposit we subtract `msg.value`.

Example:

```text
Pool reserve before deposit: 10 ETH
User sends: 1 ETH

address(this).balance = 11 ETH
ethReserve = 11 - 1 = 10 ETH
```

This is a very important detail in the Uniswap V1 implementation.

---

## Token reserve calculation

```solidity
uint256 tokenReserve = i_token.balanceOf(address(this));
```

This reads the current token reserve of the pool.

Example:

```text
20,000 DAI
```

---

## Required token amount

```solidity
uint256 tokenAmount =
    msg.value * tokenReserve / ethReserve + 1;
```

This formula ensures that liquidity is added proportionally to the current reserve ratio.

Example:

```text
ETH reserve = 10 ETH
Token reserve = 20,000 DAI
User deposits = 1 ETH
```

Required token amount:

$$
\frac{1 \cdot 20000}{10} = 2000\ \text{DAI}
$$

The `+1` is inherited from the original Uniswap V1 implementation and compensates for rounding caused by integer division.

---

## Liquidity minted

```solidity
uint256 liquidityMinted =
    msg.value * totalLiquidity / ethReserve;
```

LP tokens are minted proportionally to the ETH deposited.

Example:

```text
ETH reserve = 10 ETH
Total LP supply = 100 LP tokens
User deposits = 1 ETH
```

Liquidity minted:

$$
\frac{1 \cdot 100}{10} = 10
$$

The user receives:

```text
10 LP tokens
```

which represents 10% of the existing liquidity.

---

## Maximum token validation

```solidity
if (_maxTokens < tokenAmount) {
    revert UniswapV1Exchange__MaxTokensExceeded();
}
```

The user specifies the maximum amount of tokens they are willing to deposit.

If the pool requires more tokens than expected, the transaction reverts.

This protects users from reserve changes and front-running.

---

## Minimum liquidity validation

```solidity
if (liquidityMinted < _minLiquidity) {
    revert UniswapV1Exchange__InsufficientLiquidityMinted();
}
```

The user also specifies the minimum acceptable LP tokens.

If fewer LP tokens are minted, the transaction reverts.

This is another slippage protection mechanism.

---

## Minting LP tokens

```solidity
_mint(msg.sender, liquidityMinted);
```

The exchange contract acts as the LP token contract itself by inheriting from ERC20.

When liquidity is added, LP tokens are minted to the provider.

---

## Token transfer

```solidity
bool success = i_token.transferFrom(
    msg.sender,
    address(this),
    tokenAmount
);
```

The exchange transfers the required token amount from the liquidity provider into the pool.

The user must approve the exchange contract before calling `addLiquidity`.

---

## Transfer validation

```solidity
if (!success) {
    revert UniswapV1Exchange__TokenTransferFailed(
        msg.sender,
        address(this),
        tokenAmount
    );
}
```

If the token transfer fails, the transaction reverts.

Because the transaction reverts, the LP token mint is also reverted automatically.

---

## Event emission

```solidity
emit AddLiquidity(msg.sender, msg.value, tokenAmount);
```

This logs the liquidity addition.

Events are useful for:

- frontends
- indexers
- analytics platforms

---

## Returning liquidity minted

```solidity
return liquidityMinted;
```

The function returns the amount of LP tokens minted to the provider.

---

## Case 2 — First liquidity provider

```solidity
else
```

This branch runs when:

```solidity
totalLiquidity == 0
```

meaning the pool is empty.

At this point there is no market price yet.

---

## Minimum ETH requirement

```solidity
if (msg.value < 1_000_000_000) {
    revert UniswapV1Exchange__InsufficientEthAmount();
}
```

This follows the original Uniswap V1 implementation.

The first liquidity deposit must include at least:

```text
1,000,000,000 wei
```

This avoids initializing the pool with extremely tiny ETH amounts.

---

## Initial token amount

```solidity
uint256 tokenAmount = _maxTokens;
```

For the first liquidity provider:

```solidity
_maxTokens
```

is not only a maximum limit.

It becomes the exact token amount deposited.

The first provider defines the initial market price.

Example:

```text
10 ETH + 20,000 DAI
```

defines:

$$
1\ \text{ETH} = 2000\ \text{DAI}
$$

---

## Initial liquidity

```solidity
uint256 initialLiquidity = address(this).balance;
```

At this point:

```solidity
address(this).balance == msg.value
```

because this is the first deposit.

The initial LP supply becomes equal to the ETH deposited.

---

# à Minting initial LP tokens

```solidity
_mint(msg.sender, initialLiquidity);
```

The first liquidity provider receives the initial LP supply and therefore owns 100% of the pool.

---

## Initial token transfer

```solidity
bool success = i_token.transferFrom(
    msg.sender,
    address(this),
    tokenAmount
);
```

The exchange transfers the initial token reserve into the pool.

---

## Transfer validation

```solidity
if (!success) {
    revert UniswapV1Exchange__TokenTransferFailed(
        msg.sender,
        address(this),
        tokenAmount
    );
}
```

If the transfer fails, the transaction reverts together with the LP token mint.

---

## Event emission

```solidity
emit AddLiquidity(msg.sender, msg.value, tokenAmount);
```

Logs the initial liquidity addition.

---

## Returning initial liquidity

```solidity
return initialLiquidity;
```

Returns the amount of LP tokens minted to the first liquidity provider.

---

## Core formulas

The most important formulas in the function are:

```solidity
uint256 ethReserve =
    address(this).balance - msg.value;

uint256 tokenAmount =
    msg.value * tokenReserve / ethReserve + 1;

uint256 liquidityMinted =
    msg.value * totalLiquidity / ethReserve;
```

These formulas preserve the reserve ratio and mint LP tokens proportionally to the liquidity deposited.

---

## Factory validation

The original Uniswap V1 contract checks that the exchange is registered in the factory during the first liquidity deposit.

In our Solidity implementation we do not need this check inside `addLiquidity()` because the token address is fixed in the constructor.

The factory will be added later and will be responsible for deploying exchanges and registering the `token → exchange` mapping.

This keeps responsibilities separated:

- the factory manages exchange creation and registration
- the exchange manages swaps, reserves, and liquidity

