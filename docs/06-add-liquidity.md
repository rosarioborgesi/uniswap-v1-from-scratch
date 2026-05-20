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

# addLiquidity()

