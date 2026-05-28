# Factory

So far we manually deployed exchanges.

Example:

```text
DAI Exchange
USDC Exchange
WETH Exchange
```

Each exchange supports:

```text
ETH <-> ERC20 token
```

But once we introduce:

```text
Token -> Token swaps
```

the exchanges need a way to discover each other.

This is the role of the factory.

---

# Why The Factory Is Needed

Token → Token swaps in Uniswap V1 are not direct swaps.

Instead they are routed through ETH:

```text
DAI -> ETH -> USDC
```

Suppose a user wants to swap:

```text
DAI -> USDC
```

The DAI exchange needs to know:

```text
Where is the USDC exchange?
```

Without a factory, exchanges would not know how to find each other.

The factory solves this problem by maintaining a registry of exchanges.

---

# Factory Responsibilities

The factory is responsible for:

```text
creating exchanges
registering exchanges
mapping tokens to exchanges
preventing duplicate exchanges
```

The exchange contract remains responsible for:

```text
swaps
liquidity
LP tokens
reserve management
```

This separation keeps the architecture modular.

---

# Token -> Exchange Mapping

The factory stores:

```text
token address -> exchange address
```

Example:

```text
DAI   -> DAI Exchange
USDC  -> USDC Exchange
WETH  -> WETH Exchange
```

This allows exchanges to query the factory and find the correct exchange for a token.

---

# Exchange Creation

The factory deploys exchanges using:

```solidity
createExchange(address token)
```

The function:

* deploys a new exchange
* links the exchange to the token
* stores the mapping

Each token can only have one exchange.

---

# Preventing Duplicate Exchanges

The factory must prevent:

```text
multiple exchanges for the same token
```

Otherwise liquidity would become fragmented across pools.

Example:

```text
Two DAI exchanges
```

would create:

* different prices
* split liquidity
* routing confusion

Uniswap V1 avoids this by enforcing:

```text
1 token = 1 exchange
```

---

# Querying Exchanges

Other contracts can retrieve exchanges using:

```solidity
getExchange(address token)
```

Example:

```solidity
factory.getExchange(USDC)
```

returns:

```text
USDC Exchange address
```

This is heavily used in Token → Token swaps.

---

# Factory In Token -> Token Swaps

Suppose a user swaps:

```text
DAI -> USDC
```

The flow becomes:

```text
DAI Exchange
    |
    | asks factory
    v
Factory -> returns USDC Exchange
    |
    v
USDC Exchange executes ETH -> USDC swap
```

So the factory acts as the routing registry of the protocol.

---

# Relationship Between Factory And Exchange

The architecture becomes:

```text
Factory
    |
    | deploys
    v
Exchange
```

and:

```text
Exchange
    |
    | queries
    v
Factory
```

The factory creates exchanges, while exchanges use the factory to discover other exchanges.

---

# Minimal Factory Design

For our implementation we only need a minimal factory.

At minimum we will implement:

```solidity
createExchange(address token)
getExchange(address token)
```

Later we may also add:

* exchange -> token mappings
* arrays of all exchanges
* helper getters

---

# Next Step

Once the factory is implemented, we can finally support:

```text
Token -> Token swaps
```

using the flow:

```text
Token A
    ↓
ETH
    ↓
Token B
```
