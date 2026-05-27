// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {UniswapV1Exchange} from "src/UniswapV1Exchange.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IERC20Errors} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract UniswapV1ExchangeUnitTest is Test {
    UniswapV1Exchange public exchange;
    ERC20Mock public token;

    address user = makeAddr("user");
    address alice = makeAddr("alice");

    function setUp() external {
        token = new ERC20Mock();
        exchange = new UniswapV1Exchange(address(token), "Uniswap V1", "UNI-V1");
    }

    ///////////////////////
    //    Constructor    //
    ///////////////////////
    function test_RevertsIfTokenAddressIsZero() external {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__ZeroAddress.selector);
        new UniswapV1Exchange(address(0), "Uniswap V1", "UNI-V1");
    }

    modifier withLiquidity(uint256 ethReserve, uint256 tokenReserve) {
        // ETH reserve
        deal(address(exchange), ethReserve);
        // Token reserve
        token.mint(address(exchange), tokenReserve);
        _;
    }

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

    /////////////////////////
    //    addLiquidity     //
    /////////////////////////
    modifier addLiquidity(uint256 _ethAmount, uint256 _tokenAmount) {
        deal(address(token), user, _tokenAmount);
        deal(user, _ethAmount);

        vm.startPrank(user);
        token.approve(address(exchange), _tokenAmount);

        exchange.addLiquidity{value: _ethAmount}(0, _tokenAmount, block.timestamp + 1);
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

        uint256 liquidityMinted = exchange.addLiquidity{value: ethAmount}(0, tokenAmount, block.timestamp + 1);
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
        exchange.addLiquidity{value: ethAmount}(ethAmount, tokenAmount, block.timestamp);
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
        exchange.addLiquidity{value: ethAmount}(ethAmount, 0, block.timestamp + 1);
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
        exchange.addLiquidity(ethAmount, tokenAmount, block.timestamp + 1);
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
            exchange.addLiquidity{value: ethAmountLp2}(ethAmountLp2, tokenAmountLp2, block.timestamp + 1);
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
        exchange.addLiquidity{value: ethAmountLp2}(0, tokenAmountLp2, block.timestamp + 1);
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
        exchange.addLiquidity{value: ethAmountLp2}(ethAmountLp2, tokenAmountLp2, block.timestamp + 1);
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
        exchange.addLiquidity{value: ethAmountLp2}(ethAmountLp2 + 1, tokenAmountLp2, block.timestamp + 1);

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
            exchange.removeLiquidity(liquidityToBurn, ethAmountExpected, tokenAmountExpected, block.timestamp + 1);

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
        exchange.removeLiquidity(0, 1, 1, block.timestamp + 1);
        vm.stopPrank();
    }

    function test_RemoveLiquidityRevertsIfDeadlineExpired() external addLiquidity(10 ether, 20_000 ether) {
        vm.startPrank(user);
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__DeadlineExpired.selector);
        exchange.removeLiquidity(1 ether, 1, 1, block.timestamp);
        vm.stopPrank();
    }

    function test_RemoveLiquidityRevertsIfMinEthIsZero() external addLiquidity(10 ether, 20_000 ether) {
        vm.startPrank(user);
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__MinEthIsZero.selector);
        exchange.removeLiquidity(1 ether, 0, 1, block.timestamp + 1);
        vm.stopPrank();
    }

    function test_RemoveLiquidityRevertsIfMinTokensIsZero() external addLiquidity(10 ether, 20_000 ether) {
        vm.startPrank(user);
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__MinTokensIsZero.selector);
        exchange.removeLiquidity(1 ether, 1, 0, block.timestamp + 1);
        vm.stopPrank();
    }

    function test_RemoveLiquidityRevertsIfInsufficientEthWithdrawn() external addLiquidity(10 ether, 20_000 ether) {
        vm.startPrank(user);
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientEthWithdrawn.selector);
        exchange.removeLiquidity(1 ether, 1 ether + 1, 1, block.timestamp + 1);
        vm.stopPrank();
    }

    function test_RemoveLiquidityRevertsIfInsufficientTokensWithdrawn() external addLiquidity(10 ether, 20_000 ether) {
        vm.startPrank(user);
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientTokensWithdrawn.selector);
        exchange.removeLiquidity(1 ether, 1, 2_000 ether + 1, block.timestamp + 1);
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
        exchange.removeLiquidity(userLiquidity + 1, 1, 1, block.timestamp + 1);
        vm.stopPrank();
    }

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

        uint256 actualEthBought = exchange.tokenToEthSwapInput(tokensSold, 1, block.timestamp + 1);

        vm.stopPrank();

        assertEq(actualEthBought, ethBought);
        assertEq(address(exchange).balance, ethReserve - ethBought);
        assertEq(address(user).balance, ethBought);
        assertEq(token.balanceOf(address(exchange)), tokenReserve + tokensSold);
        assertEq(token.balanceOf(user), 0);
    }

    function test_TokenToEthSwapInputRevertsWithZeroTokensSold() external {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__TokensSoldIsZero.selector);
        exchange.tokenToEthSwapInput(0, 1, block.timestamp + 1);
    }

    function test_TokenToEthSwapInputRevertsWithZeroMinEth() external {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__MinEthIsZero.selector);
        exchange.tokenToEthSwapInput(1 ether, 0, block.timestamp + 1);
    }

    function test_TokenToEthSwapInputRevertsIfMinEthTooHigh() external withLiquidity(10 ether, 1_000 ether) {
        uint256 tokensSold = 100 ether;
        uint256 ethBought = exchange.getTokenToEthInputPrice(tokensSold);

        deal(address(token), user, tokensSold);

        vm.startPrank(user);
        token.approve(address(exchange), tokensSold);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__EthBoughtExceedsMinEth.selector);
        exchange.tokenToEthSwapInput(tokensSold, ethBought + 1, block.timestamp + 1);

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

        uint256 actualEthBought = exchange.tokenToEthTransferInput(tokensSold, 1, block.timestamp + 1, alice);

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
        exchange.tokenToEthTransferInput(tokensSold, 1, block.timestamp + 1, address(exchange));

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidRecipient.selector);
        exchange.tokenToEthTransferInput(tokensSold, 1, block.timestamp + 1, address(0));
        vm.stopPrank();
    }
}
