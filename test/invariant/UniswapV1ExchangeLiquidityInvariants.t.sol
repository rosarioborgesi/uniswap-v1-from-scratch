// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {UniswapV1Exchange} from "src/UniswapV1Exchange.sol";
import {UniswapV1Factory} from "src/UniswapV1Factory.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {UniswapV1ExchangeLiquidityHandler} from "./UniswapV1ExchangeLiquidityHandler.t.sol";

contract UniswapV1ExchangeLiquidityInvariants is StdInvariant, Test {
    uint256 public constant INITIAL_ETH_RESERVE = 10 ether;
    uint256 public constant INITIAL_TOKEN_RESERVE = 1_000 ether;

    uint256 public constant HANDLER_ETH_SUPPLY = 1_000 ether;
    uint256 public constant HANDLER_TOKEN_SUPPLY = 100_000 ether;

    UniswapV1Factory public factory;
    UniswapV1Exchange public exchange;
    ERC20Mock public token;
    UniswapV1ExchangeLiquidityHandler public handler;

    function setUp() public {
        factory = new UniswapV1Factory();
        token = new ERC20Mock();

        address exchangeAddress = factory.createExchange(address(token), "Uniswap V1 Token A", "UNI-V1-A");

        exchange = UniswapV1Exchange(payable(exchangeAddress));

        // Initialize the pool once.
        // From this point, the handler can only add/remove liquidity.
        token.mint(address(this), INITIAL_TOKEN_RESERVE);
        token.approve(address(exchange), INITIAL_TOKEN_RESERVE);

        exchange.addLiquidity{value: INITIAL_ETH_RESERVE}(0, INITIAL_TOKEN_RESERVE, block.timestamp);

        handler = new UniswapV1ExchangeLiquidityHandler(exchange, token);

        deal(address(handler), HANDLER_ETH_SUPPLY);
        token.mint(address(handler), HANDLER_TOKEN_SUPPLY);

        targetContract(address(handler));
    }

    // With only addLiquidity and removeLiquidity enabled,
    // the pool size can change, but the token/ETH price ratio should stay approximately the same.
    function invariant_liquidityOperationsPreserveReserveRatio() public view {
        uint256 ethReserve = address(exchange).balance;
        uint256 tokenReserve = token.balanceOf(address(exchange));

        assertGt(ethReserve, 0);
        assertGt(tokenReserve, 0);

        uint256 initialRatio = (INITIAL_TOKEN_RESERVE * 1e18) / INITIAL_ETH_RESERVE;
        uint256 currentRatio = (tokenReserve * 1e18) / ethReserve;

        assertApproxEqAbs(initialRatio, currentRatio, 0.00001 ether);
    }
}
