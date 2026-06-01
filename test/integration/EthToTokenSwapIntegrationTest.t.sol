// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {UniswapV1Exchange} from "src/UniswapV1Exchange.sol";
import {UniswapV1IntegrationTest} from "./UniswapV1IntegrationTest.t.sol";

contract EthToTokenSwapIntegrationTest is UniswapV1IntegrationTest {
    ////////////////////
    //    receive     //
    ////////////////////
    function test_SwapDefault() external {
        uint256 tokensBought = exchangeA.getEthToTokenInputPrice(ETH_SOLD);

        deal(user, ETH_SOLD);

        vm.prank(user);
        (bool success,) = address(exchangeA).call{value: ETH_SOLD}("");

        assertTrue(success);

        assertEq(address(exchangeA).balance, ETH_RESERVE + ETH_SOLD);
        assertEq(tokenA.balanceOf(address(exchangeA)), TOKEN_RESERVE - tokensBought);

        assertEq(user.balance, 0);
        assertEq(tokenA.balanceOf(user), tokensBought);
    }

    function test_SwapDefaultRevertsIfMsgValueIsZero() external {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__EthSoldIsZero.selector);

        vm.prank(user);
        (bool success,) = address(exchangeA).call{value: 0}("");

        success;
    }

    ////////////////////////////////
    //    ethToTokenSwapInput     //
    ////////////////////////////////
    function test_SwapInput() external {
        uint256 tokensBought = exchangeA.getEthToTokenInputPrice(ETH_SOLD);

        deal(user, ETH_SOLD);

        vm.prank(user);
        uint256 actualTokensBought = exchangeA.ethToTokenSwapInput{value: ETH_SOLD}(1, block.timestamp);

        assertEq(actualTokensBought, tokensBought);

        assertEq(address(exchangeA).balance, ETH_RESERVE + ETH_SOLD);
        assertEq(tokenA.balanceOf(address(exchangeA)), TOKEN_RESERVE - tokensBought);

        assertEq(user.balance, 0);
        assertEq(tokenA.balanceOf(user), tokensBought);
    }

    ////////////////////////////////////
    //    ethToTokenTransferInput     //
    ////////////////////////////////////
    function test_TransferInput() external {
        uint256 tokensBought = exchangeA.getEthToTokenInputPrice(ETH_SOLD);

        deal(user, ETH_SOLD);

        vm.prank(user);
        uint256 actualTokensBought = exchangeA.ethToTokenTransferInput{value: ETH_SOLD}(1, block.timestamp, alice);

        assertEq(actualTokensBought, tokensBought);

        assertEq(address(exchangeA).balance, ETH_RESERVE + ETH_SOLD);
        assertEq(tokenA.balanceOf(address(exchangeA)), TOKEN_RESERVE - tokensBought);

        assertEq(user.balance, 0);
        assertEq(tokenA.balanceOf(user), 0);
        assertEq(tokenA.balanceOf(alice), tokensBought);
    }

    /////////////////////////////////
    //    ethToTokenSwapOutput     //
    /////////////////////////////////
    function test_SwapOutput() external {
        uint256 ethSold = exchangeA.getEthToTokenOutputPrice(TOKENS_BOUGHT);
        uint256 maxEth = ethSold + 1 ether;

        deal(user, maxEth);

        vm.prank(user);
        uint256 actualEthSold = exchangeA.ethToTokenSwapOutput{value: maxEth}(TOKENS_BOUGHT, block.timestamp);

        assertEq(actualEthSold, ethSold);

        assertEq(address(exchangeA).balance, ETH_RESERVE + ethSold);
        assertEq(tokenA.balanceOf(address(exchangeA)), TOKEN_RESERVE - TOKENS_BOUGHT);

        assertEq(user.balance, maxEth - ethSold);
        assertEq(tokenA.balanceOf(user), TOKENS_BOUGHT);
    }

    /////////////////////////////////////
    //    ethToTokenTransferOutput     //
    /////////////////////////////////////
    function test_TransferOutput() external {
        uint256 ethSold = exchangeA.getEthToTokenOutputPrice(TOKENS_BOUGHT);
        uint256 maxEth = ethSold + 1 ether;

        deal(user, maxEth);

        vm.prank(user);
        uint256 actualEthSold = exchangeA.ethToTokenTransferOutput{value: maxEth}(TOKENS_BOUGHT, block.timestamp, alice);

        assertEq(actualEthSold, ethSold);

        assertEq(address(exchangeA).balance, ETH_RESERVE + ethSold);
        assertEq(tokenA.balanceOf(address(exchangeA)), TOKEN_RESERVE - TOKENS_BOUGHT);

        assertEq(user.balance, maxEth - ethSold);
        assertEq(tokenA.balanceOf(user), 0);
        assertEq(tokenA.balanceOf(alice), TOKENS_BOUGHT);
    }
}
