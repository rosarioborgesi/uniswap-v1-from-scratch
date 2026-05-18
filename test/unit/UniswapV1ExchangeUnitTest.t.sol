// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {UniswapV1Exchange} from "src/UniswapV1Exchange.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract UniswapV1ExchangeUnitTest is Test {
    UniswapV1Exchange public exchange;
    ERC20Mock public token;

    address user = makeAddr("user");

    function setUp() external {
        token = new ERC20Mock();
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
    //    getInputPrice     //
    //////////////////////////
    function testGetInputPriceRevertsWithZeroInputAmount() external {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InputAmountIsZero.selector);
        exchange.getInputPrice(0, 10 ether, 1_000 ether);
    }

    function testGetInputPriceRevertsWithZeroReserves() external {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientReserves.selector);
        exchange.getInputPrice(1 ether, 0, 1_000 ether);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientReserves.selector);
        exchange.getInputPrice(1 ether, 10 ether, 0);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientReserves.selector);
        exchange.getInputPrice(1 ether, 0, 0);
    }

    ///////////////////////////////
    //     ethToTokenSwapInput   //
    ///////////////////////////////
    function testCanSwapEthForTokens() external {
        uint256 ethReserve = 10 ether;
        uint256 tokenReserve = 1_000 ether;
        uint256 ethSold = 1 ether;

        // Creating the ETH reserve
        deal(address(exchange), ethReserve);
        // Creating the token reserve
        token.mint(address(exchange), tokenReserve);

        deal(user, ethSold);

        uint256 tokensBought = exchange.getEthToTokenInputPrice(ethSold);

        vm.prank(user);
        uint256 actualTokensBought = exchange.ethToTokenSwapInput{value: ethSold}(1, block.timestamp);

        assertEq(actualTokensBought, tokensBought);
        assertEq(address(exchange).balance, ethReserve + ethSold);
        assertEq(address(user).balance, 0);
        assertEq(token.balanceOf(address(exchange)), tokenReserve - actualTokensBought);
        assertEq(token.balanceOf(user), actualTokensBought);
    }

    function testRevertsWithZeroEthSold() external {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InputAmountIsZero.selector);

        exchange.ethToTokenSwapInput{value: 0}(1, block.timestamp);
    }

    function testRevertsWithZeroMinTokens() external {
        deal(address(exchange), 10 ether);
        token.mint(address(exchange), 1_000 ether);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientOutputAmount.selector);

        exchange.ethToTokenSwapInput{value: 1 ether}(0, block.timestamp);
    }

    function testRevertsIfMinTokensTooHigh() external {
        uint256 ethReserve = 10 ether;
        uint256 tokenReserve = 1_000 ether;
        uint256 ethSold = 1 ether;

        deal(address(exchange), ethReserve);
        token.mint(address(exchange), tokenReserve);

        uint256 tokensBought = exchange.getEthToTokenInputPrice(ethSold);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientOutputAmount.selector);

        exchange.ethToTokenSwapInput{value: ethSold}(tokensBought + 1, block.timestamp);
    }

    function testRevertsIfDeadlinePassed() external {
        deal(address(exchange), 10 ether);
        token.mint(address(exchange), 1_000 ether);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__DeadlineExpired.selector);

        exchange.ethToTokenSwapInput{value: 1 ether}(1, block.timestamp - 1);
    }
}
