// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {UniswapV1IntegrationTest} from "./UniswapV1IntegrationTest.t.sol";

contract TokenToExchangeSwapIntegrationTest is UniswapV1IntegrationTest {
    uint256 public constant TOKENS_SOLD = 100 ether;
    uint256 public constant TOKENS_BOUGHT_EXACT = 100 ether;
    uint256 public constant MAX_TOKENS_SOLD = 200 ether;

    ////////////////////////////////////
    //    tokenToExchangeSwapInput    //
    ////////////////////////////////////
    function test_SwapInput() external {
        uint256 ethBought = exchangeA.getTokenToEthInputPrice(TOKENS_SOLD);
        uint256 tokensBought = exchangeB.getEthToTokenInputPrice(ethBought);

        tokenA.mint(user, TOKENS_SOLD);

        vm.startPrank(user);
        tokenA.approve(address(exchangeA), TOKENS_SOLD);

        uint256 actualTokensBought =
            exchangeA.tokenToExchangeSwapInput(TOKENS_SOLD, 1, 1, block.timestamp + 1, payable(address(exchangeB)));

        vm.stopPrank();

        assertEq(actualTokensBought, tokensBought);

        // Updated balances of source exchange
        assertEq(address(exchangeA).balance, ETH_RESERVE - ethBought);
        assertEq(tokenA.balanceOf(address(exchangeA)), TOKEN_RESERVE + TOKENS_SOLD);

        // Updated balances of destination exchange
        assertEq(address(exchangeB).balance, ETH_RESERVE + ethBought);
        assertEq(tokenB.balanceOf(address(exchangeB)), TOKEN_RESERVE - tokensBought);

        // Updated balances of buyer
        assertEq(tokenA.balanceOf(user), 0);
        assertEq(tokenB.balanceOf(user), tokensBought);
        assertEq(user.balance, 0);
    }

    ////////////////////////////////////////
    //    tokenToExchangeTransferInput    //
    ////////////////////////////////////////
    function test_TransferInput() external {
        uint256 ethBought = exchangeA.getTokenToEthInputPrice(TOKENS_SOLD);
        uint256 tokensBought = exchangeB.getEthToTokenInputPrice(ethBought);

        tokenA.mint(user, TOKENS_SOLD);

        vm.startPrank(user);
        tokenA.approve(address(exchangeA), TOKENS_SOLD);

        uint256 actualTokensBought = exchangeA.tokenToExchangeTransferInput(
            TOKENS_SOLD, 1, 1, block.timestamp + 1, alice, payable(address(exchangeB))
        );

        vm.stopPrank();

        assertEq(actualTokensBought, tokensBought);

        // Updated balances of source exchange
        assertEq(address(exchangeA).balance, ETH_RESERVE - ethBought);
        assertEq(tokenA.balanceOf(address(exchangeA)), TOKEN_RESERVE + TOKENS_SOLD);

        // Updated balances of destination exchange
        assertEq(address(exchangeB).balance, ETH_RESERVE + ethBought);
        assertEq(tokenB.balanceOf(address(exchangeB)), TOKEN_RESERVE - tokensBought);

        // Updated balances of buyer
        assertEq(tokenA.balanceOf(user), 0);
        assertEq(tokenB.balanceOf(user), 0);
        assertEq(user.balance, 0);

        // Updated balances of recipient
        assertEq(tokenA.balanceOf(alice), 0);
        assertEq(tokenB.balanceOf(alice), tokensBought);
        assertEq(alice.balance, 0);
    }

    /////////////////////////////////////
    //    tokenToExchangeSwapOutput    //
    /////////////////////////////////////
    function test_SwapOutput() external {
        uint256 ethCost = exchangeB.getEthToTokenOutputPrice(TOKENS_BOUGHT_EXACT);
        uint256 tokensSold = exchangeA.getTokenToEthOutputPrice(ethCost);

        tokenA.mint(user, MAX_TOKENS_SOLD);

        vm.startPrank(user);
        tokenA.approve(address(exchangeA), MAX_TOKENS_SOLD);

        uint256 actualTokensSold = exchangeA.tokenToExchangeSwapOutput(
            TOKENS_BOUGHT_EXACT, MAX_TOKENS_SOLD, ethCost, block.timestamp + 1, payable(address(exchangeB))
        );

        vm.stopPrank();

        assertEq(actualTokensSold, tokensSold);

        // Updated balances of source exchange
        assertEq(address(exchangeA).balance, ETH_RESERVE - ethCost);
        assertEq(tokenA.balanceOf(address(exchangeA)), TOKEN_RESERVE + tokensSold);

        // Updated balances of destination exchange
        assertEq(address(exchangeB).balance, ETH_RESERVE + ethCost);
        assertEq(tokenB.balanceOf(address(exchangeB)), TOKEN_RESERVE - TOKENS_BOUGHT_EXACT);

        // Updated balances of buyer
        assertEq(tokenA.balanceOf(user), MAX_TOKENS_SOLD - tokensSold);
        assertEq(tokenB.balanceOf(user), TOKENS_BOUGHT_EXACT);
        assertEq(user.balance, 0);
    }

    /////////////////////////////////////////
    //    tokenToExchangeTransferOutput    //
    /////////////////////////////////////////
    function test_TransferOutput() external {
        uint256 ethCost = exchangeB.getEthToTokenOutputPrice(TOKENS_BOUGHT_EXACT);
        uint256 tokensSold = exchangeA.getTokenToEthOutputPrice(ethCost);

        tokenA.mint(user, MAX_TOKENS_SOLD);

        vm.startPrank(user);
        tokenA.approve(address(exchangeA), MAX_TOKENS_SOLD);

        uint256 actualTokensSold = exchangeA.tokenToExchangeTransferOutput(
            TOKENS_BOUGHT_EXACT, MAX_TOKENS_SOLD, ethCost, block.timestamp + 1, alice, payable(address(exchangeB))
        );

        vm.stopPrank();

        assertEq(actualTokensSold, tokensSold);

        // Updated balances of source exchange
        assertEq(address(exchangeA).balance, ETH_RESERVE - ethCost);
        assertEq(tokenA.balanceOf(address(exchangeA)), TOKEN_RESERVE + tokensSold);

        // Updated balances of destination exchange
        assertEq(address(exchangeB).balance, ETH_RESERVE + ethCost);
        assertEq(tokenB.balanceOf(address(exchangeB)), TOKEN_RESERVE - TOKENS_BOUGHT_EXACT);

        // Updated balances of buyer
        assertEq(tokenA.balanceOf(user), MAX_TOKENS_SOLD - tokensSold);
        assertEq(tokenB.balanceOf(user), 0);
        assertEq(user.balance, 0);

        // Updated balances of recipient
        assertEq(tokenA.balanceOf(alice), 0);
        assertEq(tokenB.balanceOf(alice), TOKENS_BOUGHT_EXACT);
        assertEq(alice.balance, 0);
    }
}
