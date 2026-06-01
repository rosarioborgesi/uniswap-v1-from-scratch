// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {UniswapV1Factory} from "src/UniswapV1Factory.sol";
import {UniswapV1Exchange} from "src/UniswapV1Exchange.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract UniswapV1IntegrationTest is Test {
    UniswapV1Factory public factory;

    ERC20Mock public tokenA;
    ERC20Mock public tokenB;

    UniswapV1Exchange public exchangeA;
    UniswapV1Exchange public exchangeB;

    address public user = makeAddr("user");
    address public alice = makeAddr("alice");
    address public liquidityProvider = makeAddr("liquidityProvider");

    uint256 public constant ETH_RESERVE = 10 ether;
    uint256 public constant TOKEN_RESERVE = 1_000 ether;
    uint256 public constant ETH_SOLD = 1 ether;
    uint256 public constant TOKENS_BOUGHT = 100 ether;

    function setUp() external virtual {
        factory = new UniswapV1Factory();

        tokenA = new ERC20Mock();
        tokenB = new ERC20Mock();

        address exchangeAAddress = factory.createExchange(address(tokenA), "Uniswap V1 Token A", "UNI-V1-A");

        address exchangeBAddress = factory.createExchange(address(tokenB), "Uniswap V1 Token B", "UNI-V1-B");

        exchangeA = UniswapV1Exchange(payable(exchangeAAddress));
        exchangeB = UniswapV1Exchange(payable(exchangeBAddress));

        _addLiquidity(exchangeA, tokenA, ETH_RESERVE, TOKEN_RESERVE);
        _addLiquidity(exchangeB, tokenB, ETH_RESERVE, TOKEN_RESERVE);
    }

    function _addLiquidity(UniswapV1Exchange exchange, ERC20Mock token, uint256 ethAmount, uint256 tokenAmount)
        internal
    {
        deal(liquidityProvider, ethAmount);
        token.mint(liquidityProvider, tokenAmount);

        vm.startPrank(liquidityProvider);
        token.approve(address(exchange), tokenAmount);

        exchange.addLiquidity{value: ethAmount}(0, tokenAmount, block.timestamp);

        vm.stopPrank();
    }
}
