// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {UniswapV1Factory} from "src/UniswapV1Factory.sol";
import {UniswapV1Exchange} from "src/UniswapV1Exchange.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract UniswapV1FactoryUnitTest is Test {
    UniswapV1Factory factory;
    ERC20Mock token;

    function setUp() external {
        factory = new UniswapV1Factory();
        token = new ERC20Mock();
    }

    function test_FactoryInitialState() external view {
        assertEq(factory.getExchange(address(token)), address(0));
        assertEq(factory.tokenCount(), 0);
        assertEq(factory.getTokenWithId(1), address(0));
    }

    function test_CreateExchange() external {
        address exchangeAddress = factory.createExchange(address(token), "Uniswap V1", "UNI-V1");

        assertEq(factory.getExchange(address(token)), exchangeAddress);
        assertEq(factory.getToken(exchangeAddress), address(token));
        assertEq(factory.tokenCount(), 1);
        assertEq(factory.getTokenWithId(1), address(token));

        UniswapV1Exchange exchange = UniswapV1Exchange(payable(exchangeAddress));

        assertEq(exchange.name(), "Uniswap V1");
        assertEq(exchange.symbol(), "UNI-V1");
        assertEq(exchange.decimals(), 18);
        assertEq(exchange.totalSupply(), 0);
        assertEq(exchange.tokenAddress(), address(token));
        assertEq(address(exchange).balance, 0);
        assertEq(token.balanceOf(exchangeAddress), 0);
    }

    function test_CreateExchangeRevertsIfTokenIsZeroAddress() external {
        vm.expectRevert(UniswapV1Factory.UniswapV1Factory__ZeroAddress.selector);
        factory.createExchange(address(0), "Uniswap V1", "UNI-V1");
    }

    function test_CreateExchangeRevertsIfExchangeAlreadyExists() external {
        factory.createExchange(address(token), "Uniswap V1", "UNI-V1");

        vm.expectRevert(UniswapV1Factory.UniswapV1Factory__ExchangeAlreadyExists.selector);
        factory.createExchange(address(token), "Uniswap V1", "UNI-V1");
    }
}
