// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {UniswapV1IntegrationTest} from "./UniswapV1IntegrationTest.t.sol";

contract TokenToEthSwapIntegrationTest is UniswapV1IntegrationTest {
    uint256 public constant TOKENS_SOLD = 100 ether;
    uint256 public constant ETH_BOUGHT = 1 ether;
    uint256 public constant MAX_TOKENS_SOLD = 200 ether;

    ////////////////////////////////
    //    tokenToEthSwapInput     //
    ////////////////////////////////
    function test_SwapInput() external {
        uint256 ethBought = exchangeA.getTokenToEthInputPrice(TOKENS_SOLD);

        tokenA.mint(user, TOKENS_SOLD);

        vm.startPrank(user);
        tokenA.approve(address(exchangeA), TOKENS_SOLD);

        uint256 actualEthBought = exchangeA.tokenToEthSwapInput(TOKENS_SOLD, 1, block.timestamp);

        vm.stopPrank();

        assertEq(actualEthBought, ethBought);

        // Updated balances of exchange
        assertEq(address(exchangeA).balance, ETH_RESERVE - ethBought);
        assertEq(tokenA.balanceOf(address(exchangeA)), TOKEN_RESERVE + TOKENS_SOLD);

        // Updated balances of buyer
        assertEq(tokenA.balanceOf(user), 0);
        assertEq(user.balance, ethBought);
    }

    ////////////////////////////////////
    //    tokenToEthTransferInput     //
    ////////////////////////////////////
    function test_TransferInput() external {
        uint256 ethBought = exchangeA.getTokenToEthInputPrice(TOKENS_SOLD);

        tokenA.mint(user, TOKENS_SOLD);

        vm.startPrank(user);
        tokenA.approve(address(exchangeA), TOKENS_SOLD);

        uint256 actualEthBought = exchangeA.tokenToEthTransferInput(TOKENS_SOLD, 1, block.timestamp, alice);

        vm.stopPrank();

        assertEq(actualEthBought, ethBought);

        // Updated balances of exchange
        assertEq(address(exchangeA).balance, ETH_RESERVE - ethBought);
        assertEq(tokenA.balanceOf(address(exchangeA)), TOKEN_RESERVE + TOKENS_SOLD);

        // Updated balances of buyer
        assertEq(tokenA.balanceOf(user), 0);
        assertEq(user.balance, 0);

        // Updated balances of recipient
        assertEq(tokenA.balanceOf(alice), 0);
        assertEq(alice.balance, ethBought);
    }

    /////////////////////////////////
    //    tokenToEthSwapOutput     //
    /////////////////////////////////
    function test_SwapOutput() external {
        uint256 tokensSold = exchangeA.getTokenToEthOutputPrice(ETH_BOUGHT);

        tokenA.mint(user, MAX_TOKENS_SOLD);

        vm.startPrank(user);
        tokenA.approve(address(exchangeA), MAX_TOKENS_SOLD);

        uint256 actualTokensSold = exchangeA.tokenToEthSwapOutput(ETH_BOUGHT, MAX_TOKENS_SOLD, block.timestamp);

        vm.stopPrank();

        assertEq(actualTokensSold, tokensSold);

        // Updated balances of exchange
        assertEq(address(exchangeA).balance, ETH_RESERVE - ETH_BOUGHT);
        assertEq(tokenA.balanceOf(address(exchangeA)), TOKEN_RESERVE + tokensSold);

        // Updated balances of buyer
        assertEq(tokenA.balanceOf(user), MAX_TOKENS_SOLD - tokensSold);
        assertEq(user.balance, ETH_BOUGHT);
    }

    /////////////////////////////////////
    //    tokenToEthTransferOutput     //
    /////////////////////////////////////
    function test_TransferOutput() external {
        uint256 tokensSold = exchangeA.getTokenToEthOutputPrice(ETH_BOUGHT);

        tokenA.mint(user, MAX_TOKENS_SOLD);

        vm.startPrank(user);
        tokenA.approve(address(exchangeA), MAX_TOKENS_SOLD);

        uint256 actualTokensSold =
            exchangeA.tokenToEthTransferOutput(ETH_BOUGHT, MAX_TOKENS_SOLD, block.timestamp, alice);

        vm.stopPrank();

        assertEq(actualTokensSold, tokensSold);

        // Updated balances of exchange
        assertEq(address(exchangeA).balance, ETH_RESERVE - ETH_BOUGHT);
        assertEq(tokenA.balanceOf(address(exchangeA)), TOKEN_RESERVE + tokensSold);

        // Updated balances of buyer
        assertEq(tokenA.balanceOf(user), MAX_TOKENS_SOLD - tokensSold);
        assertEq(user.balance, 0);

        // Updated balances of recipient
        assertEq(tokenA.balanceOf(alice), 0);
        assertEq(alice.balance, ETH_BOUGHT);
    }
}
