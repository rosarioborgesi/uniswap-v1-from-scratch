// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {UniswapV1Exchange} from "src/UniswapV1Exchange.sol";
import {UniswapV1ExchangeUnitTest} from "./UniswapV1ExchangeUnitTest.t.sol";

contract TokenToEthSwapUnitTest is UniswapV1ExchangeUnitTest {
    ////////////////////////////////////
    //    getTokenToEthInputPrice     //
    ////////////////////////////////////
    function test_GetTokenToEthInputPrice() external withLiquidity(10 ether, 1_000 ether) {
        uint256 tokensSold = 1_000 ether;
        uint256 expectedEthBought = exchange.getInputPrice(tokensSold, 1_000 ether, 10 ether);
        uint256 actualEthBought = exchange.getTokenToEthInputPrice(tokensSold);
        assertEq(actualEthBought, expectedEthBought);
    }

    function test_GetTokenToEthInputPriceRevertsWithZeroTokensSold() external {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__TokensSoldIsZero.selector);
        exchange.getTokenToEthInputPrice(0);
    }

    ////////////////////////////////
    //    tokenToEthSwapInput     //
    ////////////////////////////////
    function test_CanSwapTokensForEth() external withLiquidity(10 ether, 1_000 ether) {
        uint256 ethReserve = 10 ether;
        uint256 tokenReserve = 1_000 ether;
        uint256 tokensSold = 100 ether;

        deal(address(token), user, tokensSold);

        uint256 ethBought = exchange.getTokenToEthInputPrice(tokensSold);

        vm.startPrank(user);
        token.approve(address(exchange), tokensSold);

        uint256 actualEthBought = exchange.tokenToEthSwapInput(tokensSold, 1, block.timestamp);

        vm.stopPrank();

        assertEq(actualEthBought, ethBought);
        assertEq(address(exchange).balance, ethReserve - ethBought);
        assertEq(address(user).balance, ethBought);
        assertEq(token.balanceOf(address(exchange)), tokenReserve + tokensSold);
        assertEq(token.balanceOf(user), 0);
    }

    function test_TokenToEthSwapInputRevertsWithZeroTokensSold() external {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__TokensSoldIsZero.selector);
        exchange.tokenToEthSwapInput(0, 1, block.timestamp);
    }

    function test_TokenToEthSwapInputRevertsWithZeroMinEth() external {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__MinEthIsZero.selector);
        exchange.tokenToEthSwapInput(1 ether, 0, block.timestamp);
    }

    function test_TokenToEthSwapInputRevertsIfMinEthTooHigh() external withLiquidity(10 ether, 1_000 ether) {
        uint256 tokensSold = 100 ether;
        uint256 ethBought = exchange.getTokenToEthInputPrice(tokensSold);

        deal(address(token), user, tokensSold);

        vm.startPrank(user);
        token.approve(address(exchange), tokensSold);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__EthBoughtExceedsMinEth.selector);
        exchange.tokenToEthSwapInput(tokensSold, ethBought + 1, block.timestamp);

        vm.stopPrank();
    }

    function test_TokenToEthSwapInputRevertsIfDeadlinePassed() external withLiquidity(10 ether, 1_000 ether) {
        uint256 tokensSold = 100 ether;

        deal(address(token), user, tokensSold);

        vm.startPrank(user);
        token.approve(address(exchange), tokensSold);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__DeadlineExpired.selector);
        exchange.tokenToEthSwapInput(tokensSold, 1, block.timestamp - 1);

        vm.stopPrank();
    }

    ////////////////////////////////////
    //    tokenToEthTransferInput     //
    ////////////////////////////////////
    function test_CanSwapTokensForEthAndTransferToRecipient() external withLiquidity(10 ether, 1_000 ether) {
        uint256 ethReserve = 10 ether;
        uint256 tokenReserve = 1_000 ether;
        uint256 tokensSold = 100 ether;

        deal(address(token), user, tokensSold);

        uint256 ethBought = exchange.getTokenToEthInputPrice(tokensSold);

        vm.startPrank(user);
        token.approve(address(exchange), tokensSold);

        uint256 actualEthBought = exchange.tokenToEthTransferInput(tokensSold, 1, block.timestamp, alice);

        vm.stopPrank();

        assertEq(actualEthBought, ethBought);
        assertEq(address(exchange).balance, ethReserve - ethBought);
        assertEq(address(user).balance, 0);
        assertEq(address(alice).balance, ethBought);
        assertEq(token.balanceOf(address(exchange)), tokenReserve + tokensSold);
        assertEq(token.balanceOf(user), 0);
    }

    function test_TokenToEthTransferInputRevertsOnInvalidRecipient() external withLiquidity(10 ether, 1_000 ether) {
        uint256 tokensSold = 100 ether;

        deal(address(token), user, tokensSold);

        vm.startPrank(user);
        token.approve(address(exchange), tokensSold);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidRecipient.selector);
        exchange.tokenToEthTransferInput(tokensSold, 1, block.timestamp, address(exchange));

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidRecipient.selector);
        exchange.tokenToEthTransferInput(tokensSold, 1, block.timestamp, address(0));
        vm.stopPrank();
    }

    //////////////////////////////////////
    //    getTokenToEthOutputPrice     //
    //////////////////////////////////////
    function test_GetTokenToEthOutputPrice() external withLiquidity(10 ether, 1_000 ether) {
        uint256 ethBought = 1 ether;

        uint256 expectedTokensSold = exchange.getOutputPrice(ethBought, 1_000 ether, 10 ether);

        uint256 actualTokensSold = exchange.getTokenToEthOutputPrice(ethBought);

        assertEq(actualTokensSold, expectedTokensSold);
    }

    function test_GetTokenToEthOutputPriceRevertsWithZeroEthBought() external {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__EthBoughtIsZero.selector);
        exchange.getTokenToEthOutputPrice(0);
    }

    ////////////////////////////////
    //    tokenToEthSwapOutput    //
    ////////////////////////////////
    function test_CanSwapTokensForExactEth() external withLiquidity(10 ether, 1_000 ether) {
        uint256 ethReserve = 10 ether;
        uint256 tokenReserve = 1_000 ether;
        uint256 ethBought = 1 ether;

        uint256 tokensSold = exchange.getTokenToEthOutputPrice(ethBought);

        deal(address(token), user, tokensSold);

        vm.startPrank(user);
        token.approve(address(exchange), tokensSold);

        uint256 actualTokensSold = exchange.tokenToEthSwapOutput(ethBought, tokensSold, block.timestamp);

        vm.stopPrank();

        assertEq(actualTokensSold, tokensSold);
        assertEq(address(user).balance, ethBought);
        assertEq(address(exchange).balance, ethReserve - ethBought);
        assertEq(token.balanceOf(user), 0);
        assertEq(token.balanceOf(address(exchange)), tokenReserve + tokensSold);
    }

    function test_TokenToEthSwapOutputRevertsIfTokensSoldExceedsMaxTokens()
        external
        withLiquidity(10 ether, 1_000 ether)
    {
        uint256 ethBought = 1 ether;
        uint256 tokensSold = exchange.getTokenToEthOutputPrice(ethBought);

        deal(address(token), user, tokensSold);

        vm.startPrank(user);
        token.approve(address(exchange), tokensSold);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__TokensSoldExceedsMaxTokens.selector);
        exchange.tokenToEthSwapOutput(ethBought, tokensSold - 1, block.timestamp);

        vm.stopPrank();
    }

    function test_TokenToEthSwapOutputRevertsIfDeadlinePassed() external withLiquidity(10 ether, 1_000 ether) {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__DeadlineExpired.selector);
        exchange.tokenToEthSwapOutput(1 ether, 1_000 ether, block.timestamp -1);
    }

    function test_TokenToEthSwapOutputRevertsWithZeroEthBought() external withLiquidity(10 ether, 1_000 ether) {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__EthBoughtIsZero.selector);
        exchange.tokenToEthSwapOutput(0, 1_000 ether, block.timestamp);
    }

    ////////////////////////////////////
    //    tokenToEthTransferOutput    //
    ////////////////////////////////////
    function test_CanSwapTokensForExactEthAndTransferToRecipient() external withLiquidity(10 ether, 1_000 ether) {
        uint256 ethReserve = 10 ether;
        uint256 tokenReserve = 1_000 ether;
        uint256 ethBought = 1 ether;

        uint256 tokensSold = exchange.getTokenToEthOutputPrice(ethBought);

        deal(address(token), user, tokensSold);

        vm.startPrank(user);
        token.approve(address(exchange), tokensSold);

        uint256 actualTokensSold = exchange.tokenToEthTransferOutput(ethBought, tokensSold, block.timestamp, alice);

        vm.stopPrank();

        assertEq(actualTokensSold, tokensSold);
        assertEq(address(alice).balance, ethBought);
        assertEq(address(user).balance, 0);
        assertEq(address(exchange).balance, ethReserve - ethBought);
        assertEq(token.balanceOf(user), 0);
        assertEq(token.balanceOf(address(exchange)), tokenReserve + tokensSold);
    }

    function test_TokenToEthTransferOutputRevertsOnInvalidRecipient() external withLiquidity(10 ether, 1_000 ether) {
        uint256 ethBought = 1 ether;
        uint256 tokensSold = exchange.getTokenToEthOutputPrice(ethBought);

        deal(address(token), user, tokensSold);

        vm.startPrank(user);
        token.approve(address(exchange), tokensSold);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidRecipient.selector);
        exchange.tokenToEthTransferOutput(ethBought, tokensSold, block.timestamp, address(exchange));

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidRecipient.selector);
        exchange.tokenToEthTransferOutput(ethBought, tokensSold, block.timestamp, address(0));

        vm.stopPrank();
    }
}
