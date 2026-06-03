// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {UniswapV1Exchange} from "src/UniswapV1Exchange.sol";
import {UniswapV1Factory} from "src/UniswapV1Factory.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {UniswapV1ExchangeHandler} from "./UniswapV1ExchangeHandler.t.sol";

contract UniswapV1ExchangeInvariants is StdInvariant, Test {
    uint256 public constant INITIAL_TOKEN_SUPPLY = 100_000_000 ether;
    uint256 public constant INITIAL_ETH_SUPPLY = 100_000 ether;
    uint256 public constant ACTORS = 4;

    UniswapV1Factory public factory;
    UniswapV1Exchange public exchange;
    ERC20Mock public token;
    UniswapV1ExchangeHandler public handler;

    function setUp() public {
        factory = new UniswapV1Factory();
        token = new ERC20Mock();
        address exchangeAddress = factory.createExchange(address(token), "Uniswap V1 Token A", "UNI-V1-A");
        exchange = UniswapV1Exchange(payable(exchangeAddress));

        // The handler creates ACTORS addresses and distributes the initial ETH and token supply to them.
        //
        // From this point on, no new ETH or tokens are introduced into the system.
        // Assets can only move between:
        // - actors
        // - exchange
        //
        // Therefore, INITIAL_ETH_SUPPLY and INITIAL_TOKEN_SUPPLY represent the total closed-system supply.
        handler = new UniswapV1ExchangeHandler(exchange, token, INITIAL_ETH_SUPPLY, INITIAL_TOKEN_SUPPLY, ACTORS);

        targetContract(address(handler));
    }

    // Ghost accounting tracks what should be inside the exchange.
    //
    // Expected exchange reserve = total deposited by actors - total withdrawn by actors.
    //
    // The real ETH and token balances of the exchange must always match
    // the values computed from the ghost variables.
    function invariant_ExchangeBalancesMatchExpectedReserves() public view {
        assertEq(address(exchange).balance, handler.ghost_ethDeposited() - handler.ghost_ethWithdrawn());
        assertEq(token.balanceOf(address(exchange)), handler.ghost_tokensDeposited() - handler.ghost_tokensWithdrawn());
    }

    // The actors are funded with INITIAL_ETH_SUPPLY during handler construction.
    //
    // During these invariant tests, ETH can only move between actors and the exchange:
    // - addLiquidity moves ETH from an actor to the exchange
    // - removeLiquidity moves ETH from the exchange back to an actor
    // - ETH -> Token swaps move ETH from an actor to the exchange
    // - Token -> ETH swaps move ETH from the exchange back to an actor
    //
    // Since no ETH leaves this closed system, the sum of all actor balances
    // plus the exchange ETH balance must always equal the initial ETH supply.
    function invariant_conservationOfETH() public view {
        uint256 actorsEthBalance;

        address[] memory actors = handler.getActors();

        for (uint256 i = 0; i < actors.length; i++) {
            actorsEthBalance += actors[i].balance;
            console.log(actors[i].balance);
        }

        assertEq(INITIAL_ETH_SUPPLY, actorsEthBalance + address(exchange).balance);
    }

    // The actors are funded with INITIAL_TOKEN_SUPPLY during handler construction.
    //
    // During these invariant tests, tokens can only move between actors and the exchange:
    // - addLiquidity transfers tokens from an actor to the exchange
    // - removeLiquidity transfers tokens from the exchange back to an actor
    // - Token -> ETH swaps transfer tokens from an actor to the exchange
    // - ETH -> Token swaps transfer tokens from the exchange back to an actor
    //
    // Since no tokens leave this closed system, the sum of all actor token balances
    // plus the exchange token balance must always equal the initial token supply.
    function invariant_conservationOfTokens() public view {
        uint256 actorsTokenBalance;

        address[] memory actors = handler.getActors();

        for (uint256 i = 0; i < actors.length; i++) {
            actorsTokenBalance += token.balanceOf(actors[i]);
        }

        assertEq(INITIAL_TOKEN_SUPPLY, actorsTokenBalance + token.balanceOf(address(exchange)));
    }

    // The pool should never hold only one asset.
    // If ETH reserve is zero, token reserve should also be zero, and vice versa.
    function invariant_poolCannotHaveOnlyOneReserve() public view {
        uint256 ethReserve = address(exchange).balance;
        uint256 tokenReserve = token.balanceOf(address(exchange));

        assertEq(ethReserve == 0, tokenReserve == 0);
    }

    // Total LP supply should equal the sum of LP balances held by actors.
    function invariant_LpTotalSupplyEqualsSumOfActorBalances() public view {
        uint256 actorsLpBalance;

        address[] memory actors = handler.getActors();

        for (uint256 i = 0; i < actors.length; i++) {
            actorsLpBalance += exchange.balanceOf(actors[i]);
        }

        assertEq(exchange.totalSupply(), actorsLpBalance);
    }

    function invariant_callSummary() public view {
        handler.callSummary();
    }
}
