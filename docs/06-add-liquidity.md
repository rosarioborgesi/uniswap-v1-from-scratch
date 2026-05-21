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

The function has two different execution paths depending on whether the pool has already been initialized.

---

## Case 1 — Pool already initialized

If liquidity already exists:

```solidity
if (totalLiquidity > 0)
```

then new liquidity providers must deposit assets proportionally to the current reserve ratio.

Example:

```text
Pool reserves:
10 ETH
20,000 DAI
```

This means:

$$
1\ \text{ETH} = 2000\ \text{DAI}
$$

If a user wants to add:

```text
1 ETH
```

they must also deposit approximately:

```text
2000 DAI
```

otherwise the pool price would change.

The required token amount is calculated using:

$$
\text{tokenAmount} =
\frac{
\text{msg.value} \cdot \text{tokenReserve}
}{
\text{ethReserve}
}
+ 1
$$

Where:

- `msg.value` = ETH deposited by the user
- `tokenReserve` = current token reserve
- `ethReserve` = current ETH reserve before the deposit

The `+1` is inherited from the original Uniswap V1 implementation and helps avoid rounding issues caused by integer division.

---

## Important detail about ethReserve

Inside the function:

```solidity
address(this).balance
```

already includes the ETH sent in the current transaction.

To obtain the reserve before the deposit we subtract `msg.value`:

```solidity
uint256 ethReserve = address(this).balance - msg.value;
```

This is a very important detail in the Uniswap V1 implementation.

---

## Liquidity minted

LP tokens are minted proportionally to the amount of liquidity added.

The formula is:

$$
\text{liquidityMinted} =
\frac{
\text{msg.value} \cdot \text{totalLiquidity}
}{
\text{ethReserve}
}
$$

This ensures that ownership percentages remain fair for all liquidity providers.

The exchange contract itself acts as the LP token contract by inheriting from ERC20:

```solidity
contract UniswapV1Exchange is ERC20
```

and liquidity shares are minted using:

```solidity
_mint(msg.sender, liquidityMinted);
```

---

## Case 2 — First liquidity provider

If the pool is empty:

```solidity
if (totalLiquidity == 0)
```

then the first liquidity provider initializes the market.

Example:

```text
10 ETH + 20,000 DAI
```

defines:

$$
1\ \text{ETH} = 2000\ \text{DAI}
$$

Unlike later deposits, the first provider can choose any ratio because no market price exists yet.

The initial liquidity minted is:

```solidity
uint256 initialLiquidity = address(this).balance;
```

which corresponds to the ETH deposited during the first liquidity addition.

---

## Slippage protection

The function includes two important protections:

```solidity
_minLiquidity
```

Minimum amount of LP tokens the user is willing to receive.

and:

```solidity
_maxTokens
```

Maximum amount of tokens the user is willing to deposit.

If the calculated values exceed these limits, the transaction reverts.

This protects liquidity providers from unexpected reserve changes caused by front-running or price movement.

---

## Deadline protection

The function also receives:

```solidity
_deadline
```

The transaction reverts if executed after the deadline:

```solidity
if (_deadline <= block.timestamp)
```

This prevents transactions from remaining valid indefinitely and being executed later under different market conditions.


## Factory validation

The original Uniswap V1 contract checks that the exchange is registered in the factory during the first liquidity deposit.

In our Solidity implementation we do not need this check inside `addLiquidity()` because the token address is fixed in the constructor.

The factory will be added later and will be responsible for deploying exchanges and registering the `token → exchange` mapping.

This keeps responsibilities separated:

- the factory manages exchange creation and registration
- the exchange manages swaps, reserves, and liquidity

