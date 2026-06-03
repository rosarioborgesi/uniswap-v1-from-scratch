// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {UniswapV1Exchange} from "src/UniswapV1Exchange.sol";
import {UniswapV1Factory} from "src/UniswapV1Factory.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {UniswapV1ExchangeSwapHandler} from "./UniswapV1ExchangeSwapHandler.t.sol";

contract UniswapV1ExchangeSwapInvariants is StdInvariant, Test {
    uint256 public constant INITIAL_ETH_RESERVE = 10 ether;
    uint256 public constant INITIAL_TOKEN_RESERVE = 1_000 ether;

    uint256 public constant HANDLER_ETH_SUPPLY = 1_000 ether;
    uint256 public constant HANDLER_TOKEN_SUPPLY = 100_000 ether;

    UniswapV1Factory public factory;
    UniswapV1Exchange public exchange;
    ERC20Mock public token;
    UniswapV1ExchangeSwapHandler public handler;

    uint256 public initialK;

    function setUp() public {
        factory = new UniswapV1Factory();
        token = new ERC20Mock();

        address exchangeAddress = factory.createExchange(address(token), "Uniswap V1 Token A", "UNI-V1-A");

        exchange = UniswapV1Exchange(payable(exchangeAddress));

        // Add liquidity only once.
        token.mint(address(this), INITIAL_TOKEN_RESERVE);
        token.approve(address(exchange), INITIAL_TOKEN_RESERVE);

        exchange.addLiquidity{value: INITIAL_ETH_RESERVE}(0, INITIAL_TOKEN_RESERVE, block.timestamp);

        initialK = INITIAL_ETH_RESERVE * INITIAL_TOKEN_RESERVE;

        handler = new UniswapV1ExchangeSwapHandler(exchange, token);

        deal(address(handler), HANDLER_ETH_SUPPLY);
        token.mint(address(handler), HANDLER_TOKEN_SUPPLY);

        targetContract(address(handler));
    }

    // With swaps only, x * y should never decrease.
    // The price ratio can change, but fees and rounding should make k stay the same or increase.
    function invariant_kDoesNotDecrease() public view {
        uint256 ethReserve = address(exchange).balance;
        uint256 tokenReserve = token.balanceOf(address(exchange));

        uint256 currentK = ethReserve * tokenReserve;

        assertGe(currentK, initialK);
    }
}
