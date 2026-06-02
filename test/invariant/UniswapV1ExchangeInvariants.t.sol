// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {UniswapV1Exchange} from "src/UniswapV1Exchange.sol";
import {UniswapV1Factory} from "src/UniswapV1Factory.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {UniswapV1ExchangeHandler} from "./UniswapV1ExchangeHandler.t.sol";

contract UniswapV1ExchangeInvariants is StdInvariant, Test {
    UniswapV1Factory public factory;
    UniswapV1Exchange public exchange;
    ERC20Mock public token;
    UniswapV1ExchangeHandler public handler;

    function setUp() public {
        factory = new UniswapV1Factory();
        token = new ERC20Mock();
        address exchangeAddress = factory.createExchange(address(token), "Uniswap V1 Token A", "UNI-V1-A");
        exchange = UniswapV1Exchange(payable(exchangeAddress));

        handler = new UniswapV1ExchangeHandler(exchange, token);
        targetContract(address(handler));
    }

    function invariant_ExchangeBalancesMatchExpectedReserves() public view {
        assertEq(address(exchange).balance, handler.ghost_expectedEthReserve());
        assertEq(token.balanceOf(address(exchange)), handler.ghost_expectedTokenReserve());
    }

    /* function invariant_TotalSupplyEqualsEthReserve() public view {
        assertEq(exchange.totalSupply(), handler.ghost_expectedEthReserve());
    } */
}
