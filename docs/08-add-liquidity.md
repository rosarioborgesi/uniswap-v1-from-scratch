# Add Liquidity

The `addLiquidity()` function allows users to deposit:
- ETH
- ERC20 tokens

into the pool and receive LP tokens representing their ownership share.

---

# Function Signature

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
- `_minLiquidity` → minimum LP tokens expected
- `_maxTokens` → maximum tokens willing to deposit
- `_deadline` → transaction expiration timestamp

The function returns the amount of LP tokens minted.

---

# Two Execution Paths

The logic differs depending on whether the pool already exists.

```text
1. Pool already initialized
2. First liquidity provider
```

---

# Initialized Pool

If liquidity already exists:

```solidity
if (totalLiquidity > 0)
```

new deposits must preserve the reserve ratio.

---

# Reserve Reconstruction

Inside a payable function:

```solidity
address(this).balance
```

already includes:

```solidity
msg.value
```

So the ETH reserve before the deposit is reconstructed with:

```solidity
uint256 ethReserve =
    address(this).balance - msg.value;
```

Token reserve:

```solidity
uint256 tokenReserve =
    i_token.balanceOf(address(this));
```

---

# Required Token Amount

The required token deposit is:

$$
\text{tokenAmount} =
\frac{
\text{msg.value} \cdot \text{tokenReserve}
}{
\text{ethReserve}
}
$$

Implementation:

```solidity
uint256 tokenAmount =
    msg.value * tokenReserve / ethReserve + 1;
```

The `+1` compensates for Solidity integer rounding.

---

# Liquidity Minted

LP tokens are minted proportionally to the ETH deposited.

Formula:

$$
\text{liquidityMinted} =
\frac{
\text{msg.value} \cdot \text{totalLiquidity}
}{
\text{ethReserve}
}
$$

This preserves ownership proportions fairly.

---

# Slippage Protection

The function includes two protections.

---

## Maximum Token Protection

```solidity
if (_maxTokens < tokenAmount)
```

The user refuses to deposit more tokens than expected.

---

## Minimum Liquidity Protection

```solidity
if (liquidityMinted < _minLiquidity)
```

The user refuses to receive fewer LP tokens than expected.

---

# LP Token Minting

The exchange contract inherits from ERC20.

LP tokens are minted using:

```solidity
_mint(msg.sender, liquidityMinted);
```

The provider receives ownership shares of the pool.

---

# Token Transfer

The exchange pulls tokens from the provider:

```solidity
i_token.transferFrom(
    msg.sender,
    address(this),
    tokenAmount
);
```

The provider must approve the exchange before calling `addLiquidity()`.

---

# First Liquidity Provider

If:

```solidity
totalLiquidity == 0
```

the pool is empty.

The first liquidity provider:
- initializes the pool
- defines the initial market price
- receives the initial LP supply

---

# Initial Price

Example:

```text
10 ETH + 20,000 DAI
```

defines:

```text
1 ETH = 2000 DAI
```

At this stage there is no existing reserve ratio to preserve.

---

# Initial LP Supply

The initial LP supply is:

```solidity
uint256 initialLiquidity =
    address(this).balance;
```

which equals:

```solidity
msg.value
```

The first provider therefore owns 100% of the pool.

---

# Factory Validation

The original Uniswap V1 implementation validates the exchange through the factory during the first liquidity deposit.

In our Solidity implementation this validation is unnecessary inside `addLiquidity()` because:
- the token is fixed in the constructor
- the factory will later handle exchange deployment and registration

This keeps responsibilities separated:
- factory → exchange creation
- exchange → swaps and liquidity management

---

# Flow Summary

The add liquidity flow becomes:

```text
Validate inputs
        ↓
Read reserves
        ↓
Calculate required tokens
        ↓
Calculate LP tokens minted
        ↓
Transfer tokens
        ↓
Mint LP tokens
```