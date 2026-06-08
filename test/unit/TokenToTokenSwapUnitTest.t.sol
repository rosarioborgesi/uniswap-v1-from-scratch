// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {UniswapV1Exchange} from "src/UniswapV1Exchange.sol";
import {UniswapV1Factory} from "src/UniswapV1Factory.sol";
import {ERC20Mock} from "openzeppelin-contracts/mocks/token/ERC20Mock.sol";

contract TokenToTokenSwapUnitTest is Test {
    UniswapV1Factory factory;

    ERC20Mock tokenA;
    ERC20Mock tokenB;

    UniswapV1Exchange exchangeA;
    UniswapV1Exchange exchangeB;

    address user = makeAddr("user");
    address alice = makeAddr("alice");

    function setUp() external {
        factory = new UniswapV1Factory();

        tokenA = new ERC20Mock();
        tokenB = new ERC20Mock();

        address exchangeAAddress = factory.createExchange(address(tokenA), "UNI-V1-A", "UNI-A");
        address exchangeBAddress = factory.createExchange(address(tokenB), "UNI-V1-B", "UNI-B");

        exchangeA = UniswapV1Exchange(payable(exchangeAAddress));
        exchangeB = UniswapV1Exchange(payable(exchangeBAddress));
    }

    modifier withTokenToTokenLiquidity() {
        deal(address(exchangeA), 10 ether);
        deal(address(exchangeB), 10 ether);

        tokenA.mint(address(exchangeA), 1_000 ether);
        tokenB.mint(address(exchangeB), 1_000 ether);
        _;
    }

    /////////////////////////////////
    //    tokenToTokenSwapInput    //
    /////////////////////////////////
    function test_CanSwapTokenAToTokenB() external withTokenToTokenLiquidity {
        uint256 tokensSold = 100 ether;

        deal(address(tokenA), user, tokensSold);

        uint256 ethBought = exchangeA.getTokenToEthInputPrice(tokensSold);
        uint256 tokensBought = exchangeB.getEthToTokenInputPrice(ethBought);

        vm.startPrank(user);
        tokenA.approve(address(exchangeA), tokensSold);

        uint256 actualTokensBought = exchangeA.tokenToTokenSwapInput(tokensSold, 1, 1, block.timestamp, address(tokenB));

        vm.stopPrank();

        assertEq(actualTokensBought, tokensBought);
        assertEq(tokenA.balanceOf(user), 0);
        assertEq(tokenB.balanceOf(user), tokensBought);

        assertEq(tokenA.balanceOf(address(exchangeA)), 1_000 ether + tokensSold);
        assertEq(address(exchangeA).balance, 10 ether - ethBought);

        assertEq(address(exchangeB).balance, 10 ether + ethBought);
        assertEq(tokenB.balanceOf(address(exchangeB)), 1_000 ether - tokensBought);
    }

    function test_TokenToTokenInputRevertsWithZeroTokensSold() external withTokenToTokenLiquidity {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__TokensSoldIsZero.selector);

        exchangeA.tokenToTokenSwapInput(0, 1, 1, block.timestamp, address(tokenB));
    }

    function test_TokenToTokenInputRevertsWithZeroMinTokensBought() external withTokenToTokenLiquidity {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__MinTokensBoughtIsZero.selector);
        exchangeA.tokenToTokenSwapInput(100 ether, 0, 1, block.timestamp, address(tokenB));
    }

    function test_TokenToTokenInputRevertsWithZeroMinEthBought() external withTokenToTokenLiquidity {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__MinEthBoughtIsZero.selector);
        exchangeA.tokenToTokenSwapInput(100 ether, 1, 0, block.timestamp, address(tokenB));
    }

    function test_TokenToTokenInputRevertsIfDeadlinePassed() external withTokenToTokenLiquidity {
        uint256 tokensSold = 100 ether;

        deal(address(tokenA), user, tokensSold);

        vm.startPrank(user);
        tokenA.approve(address(exchangeA), tokensSold);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__DeadlineExpired.selector);

        exchangeA.tokenToTokenSwapInput(tokensSold, 1, 1, block.timestamp - 1, address(tokenB));

        vm.stopPrank();
    }

    function test_TokenToTokenInputRevertsIfMinEthBoughtTooHigh() external withTokenToTokenLiquidity {
        uint256 tokensSold = 100 ether;
        uint256 ethBought = exchangeA.getTokenToEthInputPrice(tokensSold);

        deal(address(tokenA), user, tokensSold);

        vm.startPrank(user);
        tokenA.approve(address(exchangeA), tokensSold);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientEthBought.selector);

        exchangeA.tokenToTokenSwapInput(tokensSold, 1, ethBought + 1, block.timestamp, address(tokenB));

        vm.stopPrank();
    }

    function test_TokenToTokenInputRevertsIfMinTokensBoughtTooHigh() external withTokenToTokenLiquidity {
        uint256 tokensSold = 100 ether;

        uint256 ethBought = exchangeA.getTokenToEthInputPrice(tokensSold);
        uint256 tokensBought = exchangeB.getEthToTokenInputPrice(ethBought);

        deal(address(tokenA), user, tokensSold);

        vm.startPrank(user);
        tokenA.approve(address(exchangeA), tokensSold);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientTokensBought.selector);

        exchangeA.tokenToTokenSwapInput(tokensSold, tokensBought + 1, 1, block.timestamp, address(tokenB));

        vm.stopPrank();
    }

    function test_TokenToTokenInputRevertsIfOutputTokenHasNoExchange() external withTokenToTokenLiquidity {
        ERC20Mock tokenC = new ERC20Mock();
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidExchangeAddress.selector);
        exchangeA.tokenToTokenSwapInput(100 ether, 1, 1, block.timestamp, address(tokenC));
    }

    function test_TokenToTokenInputRevertsIfOutputTokenIsSameToken() external withTokenToTokenLiquidity {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidExchangeAddress.selector);
        exchangeA.tokenToTokenSwapInput(100 ether, 1, 1, block.timestamp, address(tokenA));
    }

    /////////////////////////////////////
    //    tokenToTokenTransferInput    //
    /////////////////////////////////////
    function test_CanSwapTokenAToTokenBAndTransferToRecipient() external withTokenToTokenLiquidity {
        uint256 tokensSold = 100 ether;

        deal(address(tokenA), user, tokensSold);

        uint256 ethBought = exchangeA.getTokenToEthInputPrice(tokensSold);
        uint256 tokensBought = exchangeB.getEthToTokenInputPrice(ethBought);

        vm.startPrank(user);
        tokenA.approve(address(exchangeA), tokensSold);

        uint256 actualTokensBought =
            exchangeA.tokenToTokenTransferInput(tokensSold, 1, 1, block.timestamp, alice, address(tokenB));

        vm.stopPrank();

        assertEq(actualTokensBought, tokensBought);
        assertEq(tokenA.balanceOf(user), 0);
        assertEq(tokenB.balanceOf(user), 0);
        assertEq(tokenB.balanceOf(alice), tokensBought);
    }

    function test_TokenToTokenTransferInputRevertsOnInvalidRecipient() external withTokenToTokenLiquidity {
        uint256 tokensSold = 100 ether;

        deal(address(tokenA), user, tokensSold);

        vm.startPrank(user);
        tokenA.approve(address(exchangeA), tokensSold);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidRecipient.selector);
        exchangeA.tokenToTokenTransferInput(tokensSold, 1, 1, block.timestamp, address(exchangeA), address(tokenB));

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidRecipient.selector);
        exchangeA.tokenToTokenTransferInput(tokensSold, 1, 1, block.timestamp, address(0), address(tokenB));

        vm.stopPrank();
    }

    ///////////////////////////////////
    //    tokenToTokenSwapOutput     //
    ///////////////////////////////////
    function test_CanSwapTokenAToExactTokenB() external withTokenToTokenLiquidity {
        uint256 tokenAReserve = 1_000 ether;
        uint256 tokenBReserve = 1_000 ether;
        uint256 ethReserveA = 10 ether;
        uint256 ethReserveB = 10 ether;

        uint256 tokensBought = 100 ether;

        uint256 ethBought = exchangeB.getEthToTokenOutputPrice(tokensBought);
        uint256 tokensSold = exchangeA.getTokenToEthOutputPrice(ethBought);

        deal(address(tokenA), user, tokensSold);

        vm.startPrank(user);
        tokenA.approve(address(exchangeA), tokensSold);

        uint256 actualTokensSold =
            exchangeA.tokenToTokenSwapOutput(tokensBought, tokensSold, ethBought, block.timestamp, address(tokenB));

        vm.stopPrank();

        assertEq(actualTokensSold, tokensSold);

        assertEq(tokenA.balanceOf(user), 0);
        assertEq(tokenB.balanceOf(user), tokensBought);

        assertEq(tokenA.balanceOf(address(exchangeA)), tokenAReserve + tokensSold);
        assertEq(address(exchangeA).balance, ethReserveA - ethBought);

        assertEq(address(exchangeB).balance, ethReserveB + ethBought);
        assertEq(tokenB.balanceOf(address(exchangeB)), tokenBReserve - tokensBought);
    }

    function test_TokenToTokenSwapOutputRevertsIfTokensBoughtIsZero() external withTokenToTokenLiquidity {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__TokensBoughtIsZero.selector);
        exchangeA.tokenToTokenSwapOutput(0, 1, 1, block.timestamp, address(tokenB));
    }

    function test_TokenToTokenSwapOutputRevertsIfMaxEthSoldIsZero() external withTokenToTokenLiquidity {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__MaxEthSoldIsZero.selector);
        exchangeA.tokenToTokenSwapOutput(100 ether, 1_000 ether, 0, block.timestamp, address(tokenB));
    }

    function test_TokenToTokenSwapOutputRevertsIfDeadlinePassed() external withTokenToTokenLiquidity {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__DeadlineExpired.selector);
        exchangeA.tokenToTokenSwapOutput(100 ether, 1_000 ether, 1 ether, block.timestamp - 1, address(tokenB));
    }

    function test_TokenToTokenSwapOutputRevertsIfEthBoughtExceedsMaxEthSold() external withTokenToTokenLiquidity {
        uint256 tokensBought = 100 ether;
        uint256 ethBought = exchangeB.getEthToTokenOutputPrice(tokensBought);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__EthBoughtExceedsMaxEthSold.selector);

        exchangeA.tokenToTokenSwapOutput(
            tokensBought, type(uint256).max, ethBought - 1, block.timestamp, address(tokenB)
        );
    }

    function test_TokenToTokenSwapOutputRevertsIfTokensSoldExceedsMaxTokensSold() external withTokenToTokenLiquidity {
        uint256 tokensBought = 100 ether;

        uint256 ethBought = exchangeB.getEthToTokenOutputPrice(tokensBought);
        uint256 tokensSold = exchangeA.getTokenToEthOutputPrice(ethBought);

        deal(address(tokenA), user, tokensSold);

        vm.startPrank(user);
        tokenA.approve(address(exchangeA), tokensSold);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__TokensSoldExceedsMaxTokensSold.selector);

        exchangeA.tokenToTokenSwapOutput(tokensBought, tokensSold - 1, ethBought, block.timestamp, address(tokenB));

        vm.stopPrank();
    }

    function test_TokenToTokenSwapOutputRevertsIfOutputTokenHasNoExchange() external withTokenToTokenLiquidity {
        ERC20Mock tokenC = new ERC20Mock();
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidExchangeAddress.selector);
        exchangeA.tokenToTokenSwapOutput(100 ether, 1_000 ether, 1 ether, block.timestamp, address(tokenC));
    }

    function test_TokenToTokenSwapOutputRevertsIfOutputTokenIsSameToken() external withTokenToTokenLiquidity {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidExchangeAddress.selector);
        exchangeA.tokenToTokenSwapOutput(100 ether, 1_000 ether, 1 ether, block.timestamp, address(tokenA));
    }

    ///////////////////////////////////////
    //    tokenToTokenTransferOutput     //
    ///////////////////////////////////////
    function test_CanSwapTokenAToExactTokenBAndTransferToRecipient() external withTokenToTokenLiquidity {
        uint256 tokenAReserve = 1_000 ether;
        uint256 tokenBReserve = 1_000 ether;
        uint256 ethReserveA = 10 ether;
        uint256 ethReserveB = 10 ether;

        uint256 tokensBought = 100 ether;

        uint256 ethBought = exchangeB.getEthToTokenOutputPrice(tokensBought);
        uint256 tokensSold = exchangeA.getTokenToEthOutputPrice(ethBought);

        deal(address(tokenA), user, tokensSold);

        vm.startPrank(user);
        tokenA.approve(address(exchangeA), tokensSold);

        uint256 actualTokensSold = exchangeA.tokenToTokenTransferOutput(
            tokensBought, tokensSold, ethBought, block.timestamp, alice, address(tokenB)
        );

        vm.stopPrank();

        assertEq(actualTokensSold, tokensSold);

        assertEq(tokenA.balanceOf(user), 0);
        assertEq(tokenB.balanceOf(user), 0);
        assertEq(tokenB.balanceOf(alice), tokensBought);

        assertEq(tokenA.balanceOf(address(exchangeA)), tokenAReserve + tokensSold);
        assertEq(address(exchangeA).balance, ethReserveA - ethBought);

        assertEq(address(exchangeB).balance, ethReserveB + ethBought);
        assertEq(tokenB.balanceOf(address(exchangeB)), tokenBReserve - tokensBought);
    }

    function test_TokenToTokenTransferOutputRevertsOnInvalidRecipient() external withTokenToTokenLiquidity {
        uint256 tokensBought = 100 ether;

        uint256 ethBought = exchangeB.getEthToTokenOutputPrice(tokensBought);
        uint256 tokensSold = exchangeA.getTokenToEthOutputPrice(ethBought);

        deal(address(tokenA), user, tokensSold);

        vm.startPrank(user);
        tokenA.approve(address(exchangeA), tokensSold);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidRecipient.selector);
        exchangeA.tokenToTokenTransferOutput(
            tokensBought, tokensSold, ethBought, block.timestamp, address(exchangeA), address(tokenB)
        );

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidRecipient.selector);
        exchangeA.tokenToTokenTransferOutput(
            tokensBought, tokensSold, ethBought, block.timestamp, address(0), address(tokenB)
        );

        vm.stopPrank();
    }
}
