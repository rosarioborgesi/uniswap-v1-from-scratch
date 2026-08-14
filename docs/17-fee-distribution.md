# Fee Distribution

Uniswap V1 charges a **0.3% swap fee**. That fee is paid to liquidity providers (LPs), but it is not transferred to them after every trade.

Instead, the fee remains in the exchange contract as part of the pool reserves. LPs receive it automatically when they later remove liquidity.

---

# No Separate Fee Collector

Uniswap V1 has no fee-distributor contract, fee-collector address, or protocol-fee recipient.

Every exchange contract holds its own ETH and ERC-20 reserves. A swap changes those reserves, and the fee stays with the input asset in that same pool. As a result, all swap fees belong to the LPs who own shares of that pool.

---

# How the 0.3% Fee Is Applied

For pricing, only **99.7%** of the trader's input is used in the constant-product formula:

$$
\text{inputAmountWithFee} = \text{inputAmount} \cdot \frac{997}{1000}
$$

The remaining 0.3% is not sent anywhere else. The contract receives the trader's **full** input amount, while calculating a slightly smaller output than a fee-free swap would produce.

In the exact-input pricing function:

```solidity
uint256 inputAmountWithFee = _inputAmount * 997;
uint256 numerator = inputAmountWithFee * _outputReserve;
uint256 denominator = (_inputReserve * 1000) + inputAmountWithFee;
return numerator / denominator;
```

This difference makes the pool's constant product, `k`, increase after swaps (apart from integer-rounding effects). That increase is the on-chain record of fees accumulating for LPs.

---

# ETH → Token Example

When a trader swaps ETH for tokens:

```text
1. The trader sends ETH to the exchange.
2. The contract uses 99.7% of that ETH when calculating the token output.
3. The contract transfers tokens to the trader.
4. The full ETH input remains in the exchange's ETH balance.
```

The 0.3% fee therefore accumulates in the pool's ETH reserve. For a token → ETH swap, the same mechanism applies in reverse: the fee accumulates in the pool's token reserve.

The fee is not tracked as a separate balance. It is embedded in the current reserve balances.

---

# How LPs Receive Fees

LP tokens represent proportional ownership of the pool. If an LP owns 10% of the LP-token supply, they are entitled to 10% of the pool's current ETH reserve and 10% of its current token reserve.

When an LP removes liquidity, the exchange burns their LP tokens and calculates both withdrawals from the **current** reserves:

$$
\text{ethAmount} =
\frac{\text{liquidityBurned} \cdot \text{ethReserve}}
{\text{totalLiquidity}}
$$

$$
\text{tokenAmount} =
\frac{\text{liquidityBurned} \cdot \text{tokenReserve}}
{\text{totalLiquidity}}
$$

```solidity
ethAmount = (_amount * ethReserve) / totalLiquidity;
tokenAmount = (_amount * tokenReserve) / totalLiquidity;
```

Because the reserves include fees earned since the LP added liquidity, the withdrawal includes the LP's proportional share of those fees. There is no separate claim, collection, or distribution transaction.

---

# Important Distinction

An LP does not withdraw their original deposit plus a separately labelled fee amount. Swaps continuously change the pool's ETH/token ratio, while fees increase the pool value relative to a fee-free AMM. An LP simply withdraws their share of the pool as it exists at that time.

This means the value of an LP position also depends on price movements and the pool's changing asset composition; fees are one component of the final withdrawal value.

---

# Sources

- [Uniswap V1 whitepaper](https://hackmd.io/@HaydenAdams/HJ9jLsfTz)
- [Original Uniswap V1 exchange contract: pricing and liquidity removal](https://github.com/Uniswap/v1-contracts/blob/master/contracts/uniswap_exchange.vy#L76-L115)
