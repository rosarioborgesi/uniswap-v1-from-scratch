// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {UniswapV1Exchange} from "src/UniswapV1Exchange.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract UniswapV1ExchangeUnitTest is Test {
    UniswapV1Exchange public exchange;
    ERC20Mock public token;

    address user = makeAddr("user");
    address alice = makeAddr("alice");

    function setUp() external {
        token = new ERC20Mock();
        exchange = new UniswapV1Exchange(address(token), address(1), "Uniswap V1", "UNI-V1");
    }

    modifier withLiquidity(uint256 ethReserve, uint256 tokenReserve) {
        // ETH reserve
        deal(address(exchange), ethReserve);
        // Token reserve
        token.mint(address(exchange), tokenReserve);
        _;
    }

    ///////////////////////
    //    Constructor    //
    ///////////////////////
    function testConstructorSetsTokenCorrectly() public {
        exchange = new UniswapV1Exchange(address(token), address(1), "Uniswap V1 LP Token", "UNI-V1");
        assertEq(exchange.tokenAddress(), address(token));
    }

    function test_RevertsIfTokenAddressIsZero() external {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__TokenAddressIsZero.selector);
        new UniswapV1Exchange(address(0), address(1), "Uniswap V1", "UNI-V1");
    }

    function testCreatesExchangeWithValidLpTokenNameAndSymbol() public {
        exchange = new UniswapV1Exchange(address(token), address(1), "Uniswap V1 LP Token", "UNI-V1");

        assertEq(exchange.name(), "Uniswap V1 LP Token");
        assertEq(exchange.symbol(), "UNI-V1");
    }

    function testRevertsIfLpTokenNameIsEmpty() public {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__EmptyLpTokenName.selector);
        new UniswapV1Exchange(address(token), address(1), "", "UNI-V1");
    }

    function testRevertsIfLpTokenSymbolIsEmpty() public {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__EmptyLpTokenSymbol.selector);
        new UniswapV1Exchange(address(token), address(1), "Uniswap V1 LP Token", "");
    }
}
