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
    function testRevertsIfTokenAddressIsZero() external {
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

    ////////////////////////////////////
    //    getEthToTokenInputPrice     //
    ////////////////////////////////////
    function testGetEthToTokenInputPrice() external withLiquidity(10 ether, 1_000 ether) {
        uint256 ethSold = 1 ether;
        uint256 expectedTokensBought = exchange.getInputPrice(ethSold, 10 ether, 1_000 ether);
        uint256 actualTokensBought = exchange.getEthToTokenInputPrice(ethSold);
        assertEq(actualTokensBought, expectedTokensBought);
    }

    function testGetEthToTokenInputPriceRevertsWithZeroEthSold() external {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__EthSoldIsZero.selector);
        exchange.getEthToTokenInputPrice(0);
    }

    ///////////////////////////////
    //    ethToTokenSwapInput    //
    ///////////////////////////////
    function testCanSwapEthForTokens() external withLiquidity(10 ether, 1_000 ether) {
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

    function testSwapInputRevertsWithZeroEthSold() external {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__EthSoldIsZero.selector);
        exchange.ethToTokenSwapInput{value: 0}(1, block.timestamp);
    }

    function testRevertsWithZeroMinTokens() external withLiquidity(10 ether, 1_000 ether) {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__MinTokensIsZero.selector);
        exchange.ethToTokenSwapInput{value: 1 ether}(0, block.timestamp);
    }

    function testSwapInputRevertsIfMinTokensTooHigh() external withLiquidity(10 ether, 1_000 ether) {
        uint256 ethSold = 1 ether;

        uint256 tokensBought = exchange.getEthToTokenInputPrice(ethSold);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientOutputAmount.selector);
        exchange.ethToTokenSwapInput{value: ethSold}(tokensBought + 1, block.timestamp);
    }

    function testSwapInputRevertsIfDeadlinePassed() external withLiquidity(10 ether, 1_000 ether) {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__DeadlineExpired.selector);
        exchange.ethToTokenSwapInput{value: 1 ether}(1, block.timestamp - 1);
    }

    ///////////////////////////////////
    //    ethToTokenTransferInput    //
    ///////////////////////////////////
    function testCanSwapEthForTokensAndTransferToRecipient() external withLiquidity(10 ether, 1_000 ether) {
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

    function testEthToTokenTransferInputRevertsOnInvalidReceiver() external withLiquidity(10 ether, 1_000 ether) {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidRecipient.selector);
        exchange.ethToTokenTransferInput{value: 1 ether}(1, block.timestamp, address(exchange));

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidRecipient.selector);
        exchange.ethToTokenTransferInput{value: 1 ether}(1, block.timestamp, address(0));
    }

    //////////////////////////
    //    getOutputPrice    //
    //////////////////////////
    function testGetOutputPriceRevertsWithZeroOutputAmount() external {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__OutputAmountIsZero.selector);
        exchange.getOutputPrice(0, 10 ether, 1_000 ether);
    }

    function testGetOutputPriceRevertsWithZeroReserves() external {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientReserves.selector);
        exchange.getOutputPrice(1 ether, 0, 1_000 ether);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientReserves.selector);
        exchange.getOutputPrice(1 ether, 10 ether, 0);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientReserves.selector);
        exchange.getOutputPrice(1 ether, 0, 0);
    }

    function testGetOutputPriceRevertsWhenOutputAmountExceedsReserve() external {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__OutputAmountGreaterOrEqualThanOutputReserve.selector);
        exchange.getOutputPrice(1_000 ether, 10 ether, 1_000 ether);
    }

    ////////////////////////////////////
    //    getEthToTokenOutputPrice    //
    ////////////////////////////////////
    function testGetEthToTokenOutputPrice() external withLiquidity(10 ether, 1_000 ether) {
        uint256 tokensBought = 100 ether;
        uint256 expectedEthSold = exchange.getOutputPrice(tokensBought, 10 ether, 1_000 ether);
        uint256 actualEthSold = exchange.getEthToTokenOutputPrice(tokensBought);
        assertEq(actualEthSold, expectedEthSold);
    }

    function testGetEthToTokenOutputPriceRevertsWithZeroTokensBought() external {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__TokensBoughtIsZero.selector);
        exchange.getEthToTokenOutputPrice(0);
    }

    ////////////////////////////////
    //    ethToTokenSwapOutput    //
    ////////////////////////////////
    function testCanSwapEthForExactTokens() external withLiquidity(10 ether, 1_000 ether) {
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

    function testSwapOutputRefundsUnusedEth() external withLiquidity(10 ether, 1_000 ether) {
        uint256 tokensBought = 100 ether;

        uint256 ethSold = exchange.getEthToTokenOutputPrice(tokensBought);
        uint256 maxEth = ethSold + 1 ether;

        deal(user, maxEth);

        vm.prank(user);
        exchange.ethToTokenSwapOutput{value: maxEth}(tokensBought, block.timestamp);

        assertEq(address(user).balance, 1 ether);
    }

    function testRevertsIfEthSoldExceedsMaxEth() external withLiquidity(10 ether, 1_000 ether) {
        uint256 tokensBought = 100 ether;

        uint256 ethSold = exchange.getEthToTokenOutputPrice(tokensBought);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__EthSoldExceedsMaxEth.selector);
        exchange.ethToTokenSwapOutput{value: ethSold - 1}(tokensBought, block.timestamp);
    }

    function testSwapOutputRevertsIfDeadlinePassed() external withLiquidity(10 ether, 1_000 ether) {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__DeadlineExpired.selector);
        exchange.ethToTokenSwapOutput{value: 1 ether}(100 ether, block.timestamp - 1);
    }

    function testSwapOutputRevertsWithZeroTokensBought() external withLiquidity(10 ether, 1_000 ether) {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__TokensBoughtIsZero.selector);
        exchange.ethToTokenSwapOutput{value: 1 ether}(0, block.timestamp);
    }

    ////////////////////////////////////
    //    ethToTokenTransferOutput    //
    ///////////////////////////////////
    function testCanSwapEthForExactTokensAndTransferToRecipient() external withLiquidity(10 ether, 1_000 ether) {
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

    function testTransferOutputRefundsUnusedEth() external withLiquidity(10 ether, 1_000 ether) {
        uint256 tokensBought = 100 ether;

        uint256 ethSold = exchange.getEthToTokenOutputPrice(tokensBought);
        uint256 maxEth = ethSold + 1 ether;

        deal(user, maxEth);

        vm.prank(user);
        exchange.ethToTokenTransferOutput{value: maxEth}(tokensBought, block.timestamp, alice);

        assertEq(address(user).balance, 1 ether);
        assertEq(token.balanceOf(alice), tokensBought);
    }

    function testTransferOutputRevertsOnInvalidRecipient() external withLiquidity(10 ether, 1_000 ether) {
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

    function testAddLiquidityFirstProviderMintsInitialLiquidity() external {
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

    function testAddLiquidityRevertsIfDeadlineExpired() external {
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

    function testAddLiquidityRevertsIfMaxTokensIsZero() external {
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

    function testAddLiquidityRevertsIfMsgValueIsZero() external {
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

    function testAddLiquiditySecondProviderMintsProportionalLiquidity() external addLiquidity(10 ether, 20_000 ether) {
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

    function testAddLiquiditySecondProviderRevertsIfMinLiquidityIsZero() external addLiquidity(10 ether, 20_000 ether) {
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

    function testAddLiquiditySecondProviderRevertsIfMaxTokensExceeded() external addLiquidity(10 ether, 20_000 ether) {
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

    function testAddLiquiditySecondProviderRevertsIfInsufficientLiquidityMinted()
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

    function testLpTokensCanBeTransferred() external addLiquidity(10 ether, 20_000 ether) {
        vm.prank(user);
        exchange.transfer(alice, 1 ether);

        assertEq(exchange.balanceOf(user), 9 ether);
        assertEq(exchange.balanceOf(alice), 1 ether);
    }

    function testLpTokenTransferRevertsIfAmountExceedsBalance() external addLiquidity(10 ether, 20_000 ether) {
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
}
