// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20Errors} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {UniswapV1Exchange} from "src/UniswapV1Exchange.sol";
import {UniswapV1IntegrationTest} from "./UniswapV1IntegrationTest.t.sol";

contract LiquidityPoolIntegrationTest is UniswapV1IntegrationTest {
    function test_InitialBalances() external view {
        // User
        assertEq(tokenA.balanceOf(user), 0);
        assertEq(tokenB.balanceOf(user), 0);
        assertEq(user.balance, 0);

        // Recipient
        assertEq(tokenA.balanceOf(alice), 0);
        assertEq(tokenB.balanceOf(alice), 0);
        assertEq(alice.balance, 0);

        // Exchange A
        assertEq(address(exchangeA).balance, ETH_RESERVE);
        assertEq(tokenA.balanceOf(address(exchangeA)), TOKEN_RESERVE);
        assertEq(tokenB.balanceOf(address(exchangeA)), 0);

        // Exchange B
        assertEq(address(exchangeB).balance, ETH_RESERVE);
        assertEq(tokenA.balanceOf(address(exchangeB)), 0);
        assertEq(tokenB.balanceOf(address(exchangeB)), TOKEN_RESERVE);
    }

    function test_LiquidityPoolLifecycle() external {
        uint256 ethAdded = 2.5 ether;
        uint256 tokensNeeded = (ethAdded * TOKEN_RESERVE) / ETH_RESERVE + 1;
        uint256 tokenAmountAvailable = tokensNeeded;

        tokenA.mint(user, tokenAmountAvailable);
        deal(user, ethAdded);

        vm.startPrank(user);
        tokenA.approve(address(exchangeA), tokenAmountAvailable);

        // First liquidity provider already added liquidity in setUp()
        assertEq(exchangeA.totalSupply(), ETH_RESERVE);
        assertEq(exchangeA.balanceOf(liquidityProvider), ETH_RESERVE);
        assertEq(address(exchangeA).balance, ETH_RESERVE);
        assertEq(tokenA.balanceOf(address(exchangeA)), TOKEN_RESERVE);

        // minLiquidity == 0 while totalSupply > 0
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__MinLiquidityIsZero.selector);
        exchangeA.addLiquidity{value: ethAdded}(0, tokenAmountAvailable, block.timestamp + 1);

        // maxTokens < tokens needed
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__MaxTokensExceeded.selector);
        exchangeA.addLiquidity{value: ethAdded}(1, tokensNeeded - 1, block.timestamp + 1);

        // deadline expired
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__DeadlineExpired.selector);
        exchangeA.addLiquidity{value: ethAdded}(1, tokenAmountAvailable, block.timestamp - 1);

        // Second liquidity provider adds liquidity
        uint256 liquidityMinted = exchangeA.addLiquidity{value: ethAdded}(1, tokenAmountAvailable, block.timestamp + 1);

        vm.stopPrank();

        assertEq(liquidityMinted, ethAdded);
        assertEq(exchangeA.totalSupply(), ETH_RESERVE + ethAdded);
        assertEq(exchangeA.balanceOf(liquidityProvider), ETH_RESERVE);
        assertEq(exchangeA.balanceOf(user), ethAdded);
        assertEq(address(exchangeA).balance, ETH_RESERVE + ethAdded);
        assertEq(tokenA.balanceOf(address(exchangeA)), TOKEN_RESERVE + tokensNeeded);

        // User cannot transfer more LP tokens than owned
        vm.startPrank(user);

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user, ethAdded, ethAdded + 1)
        );
        exchangeA.transfer(alice, ethAdded + 1);

        // User transfers 1 ether LP units to alice
        exchangeA.transfer(alice, 1 ether);

        vm.stopPrank();

        assertEq(exchangeA.balanceOf(liquidityProvider), ETH_RESERVE);
        assertEq(exchangeA.balanceOf(user), ethAdded - 1 ether);
        assertEq(exchangeA.balanceOf(alice), 1 ether);
        assertEq(address(exchangeA).balance, ETH_RESERVE + ethAdded);
        assertEq(tokenA.balanceOf(address(exchangeA)), TOKEN_RESERVE + tokensNeeded);

        // removeLiquidity amount == 0
        vm.startPrank(alice);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__AmountIsZero.selector);
        exchangeA.removeLiquidity(0, 1, 1, block.timestamp + 1);

        // amount > owned liquidity
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 1 ether, 1 ether + 1)
        );
        exchangeA.removeLiquidity(1 ether + 1, 1, 1, block.timestamp + 1);

        // minEth > ETH withdrawn
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientEthWithdrawn.selector);
        exchangeA.removeLiquidity(1 ether, 1 ether + 1, 1, block.timestamp + 1);

        // minTokens > tokens withdrawn
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientTokensWithdrawn.selector);
        exchangeA.removeLiquidity(1 ether, 1, 100 ether + 1, block.timestamp + 1);

        // deadline expired
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__DeadlineExpired.selector);
        exchangeA.removeLiquidity(1 ether, 1, 1, block.timestamp - 1);

        vm.stopPrank();

        // Remove all remaining liquidity
        vm.prank(liquidityProvider);
        exchangeA.removeLiquidity(ETH_RESERVE, 1, 1, block.timestamp + 1);

        vm.prank(user);
        exchangeA.removeLiquidity(ethAdded - 1 ether, 1, 1, block.timestamp + 1);

        vm.prank(alice);
        exchangeA.removeLiquidity(1 ether, 1, 1, block.timestamp + 1);

        assertEq(exchangeA.totalSupply(), 0);
        assertEq(exchangeA.balanceOf(liquidityProvider), 0);
        assertEq(exchangeA.balanceOf(user), 0);
        assertEq(exchangeA.balanceOf(alice), 0);

        assertEq(address(exchangeA).balance, 0);
        assertEq(tokenA.balanceOf(address(exchangeA)), 0);
    }

    function test_CanAddLiquidityAgainAfterAllLiquidityIsRemoved() external {
        // Remove all initial liquidity
        vm.prank(liquidityProvider);
        exchangeA.removeLiquidity(ETH_RESERVE, 1, 1, block.timestamp + 1);

        assertEq(exchangeA.totalSupply(), 0);
        assertEq(address(exchangeA).balance, 0);
        assertEq(tokenA.balanceOf(address(exchangeA)), 0);

        // Add liquidity again as first provider
        tokenA.mint(user, TOKEN_RESERVE);
        deal(user, ETH_RESERVE);

        vm.startPrank(user);
        tokenA.approve(address(exchangeA), TOKEN_RESERVE);

        uint256 liquidityMinted = exchangeA.addLiquidity{value: ETH_RESERVE}(0, TOKEN_RESERVE, block.timestamp + 1);

        vm.stopPrank();

        assertEq(liquidityMinted, ETH_RESERVE);
        assertEq(exchangeA.totalSupply(), ETH_RESERVE);
        assertEq(exchangeA.balanceOf(user), ETH_RESERVE);
        assertEq(address(exchangeA).balance, ETH_RESERVE);
        assertEq(tokenA.balanceOf(address(exchangeA)), TOKEN_RESERVE);
    }
}
