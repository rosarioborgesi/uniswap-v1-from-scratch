// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {UniswapV1Exchange} from "src/UniswapV1Exchange.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract UniswapV1ExchangeTest is Test {
    UniswapV1Exchange public exchange;
    ERC20Mock public token;

    address user = makeAddr("user");

    function setUp() external {
        token = new ERC20Mock();
        // mint tokens to user
        exchange = new UniswapV1Exchange(address(token));
    }

    ////////////////// 
    // Constructor  //
    //////////////////
    function testRevertsIfTokenAddressIsZero() external {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__ZeroAddress.selector);
        new UniswapV1Exchange(address(0));
    }

    //////////////////////////
    // getInputPrice Tests  //
    //////////////////////////
    function testGetInputPriceRevertsWithZeroReserves() external {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientReserves.selector);
        exchange.getInputPrice(1 ether, 0, 1_000 ether);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientReserves.selector);
        exchange.getInputPrice(1 ether, 10 ether, 0);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientReserves.selector);
        exchange.getInputPrice(1 ether, 0, 0);
    }
}
