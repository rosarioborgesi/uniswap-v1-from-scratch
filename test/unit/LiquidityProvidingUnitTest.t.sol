// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {UniswapV1Exchange} from "src/UniswapV1Exchange.sol";
import {IERC20Errors} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {UniswapV1ExchangeUnitTest} from "./UniswapV1ExchangeUnitTest.t.sol";

contract LiquidityProvidingUnitTest is UniswapV1ExchangeUnitTest {
    /////////////////////////
    //    addLiquidity     //
    /////////////////////////
    modifier addLiquidity(uint256 _ethAmount, uint256 _tokenAmount) {
        deal(address(token), user, _tokenAmount);
        deal(user, _ethAmount);

        vm.startPrank(user);
        token.approve(address(exchange), _tokenAmount);

        exchange.addLiquidity{value: _ethAmount}(0, _tokenAmount, block.timestamp);
        vm.stopPrank();
        _;
    }

    function test_AddLiquidityFirstProviderMintsInitialLiquidity() external {
        uint256 ethAmount = 10 ether;
        uint256 tokenAmount = 20_000 ether;

        deal(address(token), user, tokenAmount);
        deal(user, ethAmount);

        vm.startPrank(user);
        token.approve(address(exchange), tokenAmount);

        uint256 liquidityMinted = exchange.addLiquidity{value: ethAmount}(0, tokenAmount, block.timestamp);
        vm.stopPrank();

        assertEq(liquidityMinted, ethAmount);
        assertEq(exchange.totalSupply(), ethAmount);
        assertEq(exchange.balanceOf(user), ethAmount);
        assertEq(address(exchange).balance, ethAmount);
        assertEq(token.balanceOf(address(exchange)), tokenAmount);
    }

    function test_AddLiquidityRevertsIfDeadlineExpired() external {
        uint256 ethAmount = 10 ether;
        uint256 tokenAmount = 20_000 ether;

        deal(address(token), user, tokenAmount);
        deal(user, ethAmount);

        vm.startPrank(user);
        token.approve(address(exchange), tokenAmount);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__DeadlineExpired.selector);
        exchange.addLiquidity{value: ethAmount}(ethAmount, tokenAmount, block.timestamp - 1);
        vm.stopPrank();
    }

    function test_AddLiquidityRevertsIfMaxTokensIsZero() external {
        uint256 ethAmount = 10 ether;
        uint256 tokenAmount = 20_000 ether;

        deal(address(token), user, tokenAmount);
        deal(user, ethAmount);

        vm.startPrank(user);
        token.approve(address(exchange), tokenAmount);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__MaxTokensIsZero.selector);
        exchange.addLiquidity{value: ethAmount}(ethAmount, 0, block.timestamp);
        vm.stopPrank();
    }

    function test_AddLiquidityRevertsIfMsgValueIsZero() external {
        uint256 ethAmount = 10 ether;
        uint256 tokenAmount = 20_000 ether;

        deal(address(token), user, tokenAmount);
        deal(user, ethAmount);

        vm.startPrank(user);
        token.approve(address(exchange), tokenAmount);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientEthAmount.selector);
        exchange.addLiquidity(ethAmount, tokenAmount, block.timestamp);
        vm.stopPrank();
    }

    function test_AddLiquiditySecondProviderMintsProportionalLiquidity() external addLiquidity(10 ether, 20_000 ether) {
        // First LP
        uint256 ethAmountLp1 = 10 ether;
        //uint256 tokenAmountLp1 = 20_000 ether;

        // Second LP
        uint256 ethAmountLp2 = 1 ether;
        uint256 tokenAmountLp2 = 5_000 ether;
        deal(alice, ethAmountLp2);
        deal(address(token), alice, tokenAmountLp2);

        vm.startPrank(alice);
        token.approve(address(exchange), tokenAmountLp2);
        uint256 liquidityMinted =
            exchange.addLiquidity{value: ethAmountLp2}(ethAmountLp2, tokenAmountLp2, block.timestamp);
        vm.stopPrank();

        assertEq(liquidityMinted, ethAmountLp2);
        assertEq(exchange.totalSupply(), ethAmountLp1 + ethAmountLp2);
        assertEq(exchange.balanceOf(user), ethAmountLp1);
        assertEq(exchange.balanceOf(alice), ethAmountLp2);
        assertEq(address(exchange).balance, ethAmountLp1 + ethAmountLp2);
        // Token amount LP 2 = tokenAmount = msg.value * tokenReserve / ethReserve + 1 = (1 * 20_000 / 10) + 1
        // Total token amount = Token Amount LP 1 + token amount LP 2 = 2_000 + 1 + 20_000 = 22_000 + 1
        assertEq(token.balanceOf(address(exchange)), 22_000 ether + 1);
    }

    function test_AddLiquiditySecondProviderRevertsIfMinLiquidityIsZero()
        external
        addLiquidity(10 ether, 20_000 ether)
    {
        // First LP
        //uint256 ethAmountLp1 = 10 ether;
        //uint256 tokenAmountLp1 = 20_000 ether;

        // Second LP
        uint256 ethAmountLp2 = 1 ether;
        uint256 tokenAmountLp2 = 5_000 ether;
        deal(alice, ethAmountLp2);
        deal(address(token), alice, tokenAmountLp2);

        vm.startPrank(alice);
        token.approve(address(exchange), tokenAmountLp2);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__MinLiquidityIsZero.selector);
        exchange.addLiquidity{value: ethAmountLp2}(0, tokenAmountLp2, block.timestamp);
        vm.stopPrank();
    }

    function test_AddLiquiditySecondProviderRevertsIfMaxTokensExceeded() external addLiquidity(10 ether, 20_000 ether) {
        // First LP
        //uint256 ethAmountLp1 = 10 ether;
        //uint256 tokenAmountLp1 = 20_000 ether;

        // Second LP
        uint256 ethAmountLp2 = 1 ether;
        uint256 tokenAmountLp2 = 2_000 ether;
        deal(alice, ethAmountLp2);
        deal(address(token), alice, tokenAmountLp2);

        vm.startPrank(alice);
        token.approve(address(exchange), tokenAmountLp2);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__MaxTokensExceeded.selector);
        // _maxTokens = tokenAmountLp2 = 2_000
        // tokenAmount = msg.value * tokenReserve / ethReserve + 1 = 1 * 20_000 / 10 + 1 = 2_001
        // _maxTokens < tokenAmount because 2_000 < 2_001
        exchange.addLiquidity{value: ethAmountLp2}(ethAmountLp2, tokenAmountLp2, block.timestamp);
        vm.stopPrank();
    }

    function test_AddLiquiditySecondProviderRevertsIfInsufficientLiquidityMinted()
        external
        addLiquidity(10 ether, 20_000 ether)
    {
        // Second LP
        uint256 ethAmountLp2 = 1 ether;
        uint256 tokenAmountLp2 = 5_000 ether;

        deal(alice, ethAmountLp2);
        deal(address(token), alice, tokenAmountLp2);

        vm.startPrank(alice);

        token.approve(address(exchange), tokenAmountLp2);

        // Expected liquidity minted:
        // liquidityMinted = (1 * 10) / 10 = 1 ether
        // So requesting more than 1 ether should revert

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientLiquidityMinted.selector);
        exchange.addLiquidity{value: ethAmountLp2}(ethAmountLp2 + 1, tokenAmountLp2, block.timestamp);

        vm.stopPrank();
    }

    function test_LpTokensCanBeTransferred() external addLiquidity(10 ether, 20_000 ether) {
        vm.prank(user);
        exchange.transfer(alice, 1 ether);

        assertEq(exchange.balanceOf(user), 9 ether);
        assertEq(exchange.balanceOf(alice), 1 ether);
    }

    function test_LpTokenTransferRevertsIfAmountExceedsBalance() external addLiquidity(10 ether, 20_000 ether) {
        uint256 userLiquidity = exchange.balanceOf(user);

        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, user, userLiquidity, userLiquidity + 1
            )
        );
        exchange.transfer(alice, userLiquidity + 1);
        vm.stopPrank();
    }

    ////////////////////////////
    //    removeLiquidity     //
    ////////////////////////////
    function test_RemoveLiquidityBurnsLpAndReturnsProportionalReserves() external addLiquidity(10 ether, 20_000 ether) {
        uint256 initialEthReserve = 10 ether;
        uint256 initialTokenReserve = 20_000 ether;

        uint256 liquidityToBurn = 1 ether;

        uint256 ethAmountExpected = 1 ether;
        uint256 tokenAmountExpected = 2_000 ether;

        uint256 userEthBefore = user.balance;
        uint256 userTokenBefore = token.balanceOf(user);

        vm.prank(user);
        (uint256 ethAmount, uint256 tokenAmount) =
            exchange.removeLiquidity(liquidityToBurn, ethAmountExpected, tokenAmountExpected, block.timestamp);

        assertEq(ethAmount, ethAmountExpected);
        assertEq(tokenAmount, tokenAmountExpected);

        assertEq(user.balance, userEthBefore + ethAmount);
        assertEq(token.balanceOf(user), userTokenBefore + tokenAmount);

        assertEq(exchange.balanceOf(user), 9 ether);
        assertEq(exchange.totalSupply(), 9 ether);

        assertEq(address(exchange).balance, initialEthReserve - ethAmountExpected);
        assertEq(token.balanceOf(address(exchange)), initialTokenReserve - tokenAmountExpected);
    }

    function test_RemoveLiquidityRevertsIfAmountIsZero() external addLiquidity(10 ether, 20_000 ether) {
        vm.startPrank(user);
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__AmountIsZero.selector);
        exchange.removeLiquidity(0, 1, 1, block.timestamp);
        vm.stopPrank();
    }

    function test_RemoveLiquidityRevertsIfDeadlineExpired() external addLiquidity(10 ether, 20_000 ether) {
        vm.startPrank(user);
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__DeadlineExpired.selector);
        exchange.removeLiquidity(1 ether, 1, 1, block.timestamp - 1);
        vm.stopPrank();
    }

    function test_RemoveLiquidityRevertsIfMinEthIsZero() external addLiquidity(10 ether, 20_000 ether) {
        vm.startPrank(user);
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__MinEthIsZero.selector);
        exchange.removeLiquidity(1 ether, 0, 1, block.timestamp);
        vm.stopPrank();
    }

    function test_RemoveLiquidityRevertsIfMinTokensIsZero() external addLiquidity(10 ether, 20_000 ether) {
        vm.startPrank(user);
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__MinTokensIsZero.selector);
        exchange.removeLiquidity(1 ether, 1, 0, block.timestamp);
        vm.stopPrank();
    }

    function test_RemoveLiquidityRevertsIfInsufficientEthWithdrawn() external addLiquidity(10 ether, 20_000 ether) {
        vm.startPrank(user);
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientEthWithdrawn.selector);
        exchange.removeLiquidity(1 ether, 1 ether + 1, 1, block.timestamp);
        vm.stopPrank();
    }

    function test_RemoveLiquidityRevertsIfInsufficientTokensWithdrawn() external addLiquidity(10 ether, 20_000 ether) {
        vm.startPrank(user);
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientTokensWithdrawn.selector);
        exchange.removeLiquidity(1 ether, 1, 2_000 ether + 1, block.timestamp);
        vm.stopPrank();
    }

    function test_RemoveLiquidityRevertsIfUserHasInsufficientLpBalance() external addLiquidity(10 ether, 20_000 ether) {
        uint256 userLiquidity = exchange.balanceOf(user);

        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, user, userLiquidity, userLiquidity + 1
            )
        );
        exchange.removeLiquidity(userLiquidity + 1, 1, 1, block.timestamp);
        vm.stopPrank();
    }
}
