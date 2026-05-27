// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {UniswapV1Exchange} from "src/UniswapV1Exchange.sol";
import {UniswapV1ExchangeUnitTest} from "./UniswapV1ExchangeUnitTest.t.sol";

contract EthToTokenSwapUnitTest is UniswapV1ExchangeUnitTest {
    //////////////////////////
    //    getInputPrice     //
    //////////////////////////
    function test_GetInputPriceRevertsWithZeroInputAmount() external {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InputAmountIsZero.selector);
        exchange.getInputPrice(0, 10 ether, 1_000 ether);
    }

    function test_GetInputPriceRevertsWithZeroReserves() external {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientReserves.selector);
        exchange.getInputPrice(1 ether, 0, 1_000 ether);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientReserves.selector);
        exchange.getInputPrice(1 ether, 10 ether, 0);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientReserves.selector);
        exchange.getInputPrice(1 ether, 0, 0);
    }

    ////////////////////////////////////
    //    getEthToTokenInputPrice     //
    ////////////////////////////////////
    function test_GetEthToTokenInputPrice() external withLiquidity(10 ether, 1_000 ether) {
        uint256 ethSold = 1 ether;
        uint256 expectedTokensBought = exchange.getInputPrice(ethSold, 10 ether, 1_000 ether);
        uint256 actualTokensBought = exchange.getEthToTokenInputPrice(ethSold);
        assertEq(actualTokensBought, expectedTokensBought);
    }

    function test_GetEthToTokenInputPriceRevertsWithZeroEthSold() external {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__EthSoldIsZero.selector);
        exchange.getEthToTokenInputPrice(0);
    }

    ///////////////////////////////
    //    ethToTokenSwapInput    //
    ///////////////////////////////
    function test_CanSwapEthForTokens() external withLiquidity(10 ether, 1_000 ether) {
        uint256 ethReserve = 10 ether;
        uint256 tokenReserve = 1_000 ether;
        uint256 ethSold = 1 ether;

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

    function test_SwapInputRevertsWithZeroEthSold() external {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__EthSoldIsZero.selector);
        exchange.ethToTokenSwapInput{value: 0}(1, block.timestamp);
    }

    function test_RevertsWithZeroMinTokens() external withLiquidity(10 ether, 1_000 ether) {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__MinTokensIsZero.selector);
        exchange.ethToTokenSwapInput{value: 1 ether}(0, block.timestamp);
    }

    function test_SwapInputRevertsIfMinTokensTooHigh() external withLiquidity(10 ether, 1_000 ether) {
        uint256 ethSold = 1 ether;

        uint256 tokensBought = exchange.getEthToTokenInputPrice(ethSold);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientOutputAmount.selector);
        exchange.ethToTokenSwapInput{value: ethSold}(tokensBought + 1, block.timestamp);
    }

    function test_SwapInputRevertsIfDeadlinePassed() external withLiquidity(10 ether, 1_000 ether) {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__DeadlineExpired.selector);
        exchange.ethToTokenSwapInput{value: 1 ether}(1, block.timestamp - 1);
    }

    ///////////////////////////////////
    //    ethToTokenTransferInput    //
    ///////////////////////////////////
    function test_CanSwapEthForTokensAndTransferToRecipient() external withLiquidity(10 ether, 1_000 ether) {
        uint256 ethReserve = 10 ether;
        uint256 tokenReserve = 1_000 ether;
        uint256 ethSold = 1 ether;

        deal(user, ethSold);

        uint256 tokensBought = exchange.getEthToTokenInputPrice(ethSold);

        vm.prank(user);
        uint256 actualTokensBought = exchange.ethToTokenTransferInput{value: ethSold}(1, block.timestamp, alice);

        assertEq(actualTokensBought, tokensBought);
        assertEq(address(exchange).balance, ethReserve + ethSold);
        assertEq(address(user).balance, 0);
        assertEq(token.balanceOf(address(exchange)), tokenReserve - actualTokensBought);
        assertEq(token.balanceOf(user), 0);
        assertEq(token.balanceOf(alice), tokensBought);
    }

    function test_EthToTokenTransferInputRevertsOnInvalidReceiver() external withLiquidity(10 ether, 1_000 ether) {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidRecipient.selector);
        exchange.ethToTokenTransferInput{value: 1 ether}(1, block.timestamp, address(exchange));

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidRecipient.selector);
        exchange.ethToTokenTransferInput{value: 1 ether}(1, block.timestamp, address(0));
    }

    //////////////////////////
    //    getOutputPrice    //
    //////////////////////////
    function test_GetOutputPriceRevertsWithZeroOutputAmount() external {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__OutputAmountIsZero.selector);
        exchange.getOutputPrice(0, 10 ether, 1_000 ether);
    }

    function test_GetOutputPriceRevertsWithZeroReserves() external {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientReserves.selector);
        exchange.getOutputPrice(1 ether, 0, 1_000 ether);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientReserves.selector);
        exchange.getOutputPrice(1 ether, 10 ether, 0);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientReserves.selector);
        exchange.getOutputPrice(1 ether, 0, 0);
    }

    function test_GetOutputPriceRevertsWhenOutputAmountExceedsReserve() external {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__OutputAmountGreaterOrEqualThanOutputReserve.selector);
        exchange.getOutputPrice(1_000 ether, 10 ether, 1_000 ether);
    }

    ////////////////////////////////////
    //    getEthToTokenOutputPrice    //
    ////////////////////////////////////
    function test_GetEthToTokenOutputPrice() external withLiquidity(10 ether, 1_000 ether) {
        uint256 tokensBought = 100 ether;
        uint256 expectedEthSold = exchange.getOutputPrice(tokensBought, 10 ether, 1_000 ether);
        uint256 actualEthSold = exchange.getEthToTokenOutputPrice(tokensBought);
        assertEq(actualEthSold, expectedEthSold);
    }

    function test_GetEthToTokenOutputPriceRevertsWithZeroTokensBought() external {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__TokensBoughtIsZero.selector);
        exchange.getEthToTokenOutputPrice(0);
    }

    ////////////////////////////////
    //    ethToTokenSwapOutput    //
    ////////////////////////////////
    function test_CanSwapEthForExactTokens() external withLiquidity(10 ether, 1_000 ether) {
        uint256 ethReserve = 10 ether;
        uint256 tokenReserve = 1_000 ether;
        uint256 tokensBought = 100 ether;

        uint256 ethSold = exchange.getEthToTokenOutputPrice(tokensBought);

        deal(user, ethSold);

        vm.prank(user);
        uint256 actualEthSold = exchange.ethToTokenSwapOutput{value: ethSold}(tokensBought, block.timestamp);

        assertEq(actualEthSold, ethSold);
        assertEq(token.balanceOf(user), tokensBought);
        assertEq(token.balanceOf(address(exchange)), tokenReserve - tokensBought);
        assertEq(address(user).balance, 0);
        assertEq(address(exchange).balance, ethReserve + ethSold);
    }

    function test_SwapOutputRefundsUnusedEth() external withLiquidity(10 ether, 1_000 ether) {
        uint256 tokensBought = 100 ether;

        uint256 ethSold = exchange.getEthToTokenOutputPrice(tokensBought);
        uint256 maxEth = ethSold + 1 ether;

        deal(user, maxEth);

        vm.prank(user);
        exchange.ethToTokenSwapOutput{value: maxEth}(tokensBought, block.timestamp);

        assertEq(address(user).balance, 1 ether);
    }

    function test_RevertsIfEthSoldExceedsMaxEth() external withLiquidity(10 ether, 1_000 ether) {
        uint256 tokensBought = 100 ether;

        uint256 ethSold = exchange.getEthToTokenOutputPrice(tokensBought);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__EthSoldExceedsMaxEth.selector);
        exchange.ethToTokenSwapOutput{value: ethSold - 1}(tokensBought, block.timestamp);
    }

    function test_SwapOutputRevertsIfDeadlinePassed() external withLiquidity(10 ether, 1_000 ether) {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__DeadlineExpired.selector);
        exchange.ethToTokenSwapOutput{value: 1 ether}(100 ether, block.timestamp - 1);
    }

    function test_SwapOutputRevertsWithZeroTokensBought() external withLiquidity(10 ether, 1_000 ether) {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__TokensBoughtIsZero.selector);
        exchange.ethToTokenSwapOutput{value: 1 ether}(0, block.timestamp);
    }

    ////////////////////////////////////
    //    ethToTokenTransferOutput    //
    ///////////////////////////////////
    function test_CanSwapEthForExactTokensAndTransferToRecipient() external withLiquidity(10 ether, 1_000 ether) {
        uint256 ethReserve = 10 ether;
        uint256 tokenReserve = 1_000 ether;
        uint256 tokensBought = 100 ether;

        uint256 ethSold = exchange.getEthToTokenOutputPrice(tokensBought);

        deal(user, ethSold);

        vm.prank(user);
        uint256 actualEthSold = exchange.ethToTokenTransferOutput{value: ethSold}(tokensBought, block.timestamp, alice);

        assertEq(actualEthSold, ethSold);
        assertEq(token.balanceOf(alice), tokensBought);
        assertEq(token.balanceOf(user), 0);
        assertEq(token.balanceOf(address(exchange)), tokenReserve - tokensBought);
        assertEq(address(user).balance, 0);
        assertEq(address(exchange).balance, ethReserve + ethSold);
    }

    function test_TransferOutputRefundsUnusedEth() external withLiquidity(10 ether, 1_000 ether) {
        uint256 tokensBought = 100 ether;

        uint256 ethSold = exchange.getEthToTokenOutputPrice(tokensBought);
        uint256 maxEth = ethSold + 1 ether;

        deal(user, maxEth);

        vm.prank(user);
        exchange.ethToTokenTransferOutput{value: maxEth}(tokensBought, block.timestamp, alice);

        assertEq(address(user).balance, 1 ether);
        assertEq(token.balanceOf(alice), tokensBought);
    }

    function test_TransferOutputRevertsOnInvalidRecipient() external withLiquidity(10 ether, 1_000 ether) {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidRecipient.selector);
        exchange.ethToTokenTransferOutput{value: 1 ether}(100 ether, block.timestamp, address(exchange));

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidRecipient.selector);
        exchange.ethToTokenTransferOutput{value: 1 ether}(100 ether, block.timestamp, address(0));
    }
}
