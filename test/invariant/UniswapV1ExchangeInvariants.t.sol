// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {UniswapV1Exchange} from "src/UniswapV1Exchange.sol";
import {UniswapV1Factory} from "src/UniswapV1Factory.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {UniswapV1ExchangeHandler} from "./UniswapV1ExchangeHandler.t.sol";

contract UniswapV1ExchangeInvariants is StdInvariant, Test {
    uint96 public constant INITIAL_TOKEN_SUPPLY = 100_000_000 ether;
    uint96 public constant INITIAL_ETH_SUPPLY = 100_000 ether;

    UniswapV1Factory public factory;
    UniswapV1Exchange public exchange;
    ERC20Mock public token;
    UniswapV1ExchangeHandler public handler;

    // We fund the handler once with the full ETH and token supply used in this invariant test.
    //
    // From this point on, no new ETH or tokens are introduced into the system.
    // Assets can only move between:
    // - handler
    // - exchange
    //
    // Therefore, INITIAL_ETH_SUPPLY and INITIAL_TOKEN_SUPPLY represent the total closed-system supply.
    function setUp() public {
        factory = new UniswapV1Factory();
        token = new ERC20Mock();
        address exchangeAddress = factory.createExchange(address(token), "Uniswap V1 Token A", "UNI-V1-A");
        exchange = UniswapV1Exchange(payable(exchangeAddress));

        handler = new UniswapV1ExchangeHandler(exchange, token);

        deal(address(handler), INITIAL_ETH_SUPPLY);
        token.mint(address(handler), INITIAL_TOKEN_SUPPLY);

        targetContract(address(handler));
    }

    // Ghost accounting tracks what should be inside the exchange.
    //
    // Expected reserve = total deposited - total withdrawn.
    //
    // The real ETH and token balances of the exchange must always match
    // the values computed from the ghost variables.
    function invariant_ExchangeBalancesMatchExpectedReserves() public view {
        assertEq(address(exchange).balance, handler.ghost_ethDeposited() - handler.ghost_ethWithdrawn());
        assertEq(token.balanceOf(address(exchange)), handler.ghost_tokensDeposited() - handler.ghost_tokensWithdrawn());
    }

    // The handler is funded with INITIAL_ETH_SUPPLY in setUp().
    // During these invariant tests, ETH can only move between the handler and the exchange:
    // - addLiquidity moves ETH from the handler to the exchange
    // - removeLiquidity moves ETH from the exchange back to the handler
    //
    // Since no ETH leaves this closed system, the sum of both balances
    // must always equal the initial ETH supply.
    function invariant_conservationOfETH() public view {
        assertEq(INITIAL_ETH_SUPPLY, address(handler).balance + address(exchange).balance);
    }

    // The handler is minted INITIAL_TOKEN_SUPPLY in setUp().
    // During these invariant tests, tokens can only move between the handler and the exchange:
    // - addLiquidity transfers tokens from the handler to the exchange
    // - removeLiquidity transfers tokens from the exchange back to the handler
    //
    // Since no tokens leave this closed system, the sum of both balances
    // must always equal the initial token supply.
    function invariant_conservationOfTokens() public view {
        assertEq(INITIAL_TOKEN_SUPPLY, token.balanceOf(address(handler)) + token.balanceOf(address(exchange)));
    }

    // The pool should never hold only one asset.
    // If ETH reserve is zero, token reserve should also be zero, and vice versa.
    function invariant_poolCannotHaveOnlyOneReserve() public view {
        uint256 ethReserve = address(exchange).balance;
        uint256 tokenReserve = token.balanceOf(address(exchange));

        assertEq(ethReserve == 0, tokenReserve == 0);
    }
}
