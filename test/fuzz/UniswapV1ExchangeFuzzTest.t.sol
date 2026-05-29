// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {UniswapV1Exchange} from "src/UniswapV1Exchange.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {UniswapV1Factory} from "src/UniswapV1Factory.sol";

contract UniswapV1ExchangeFuzzTest is Test {
    UniswapV1Exchange public exchange;
    ERC20Mock public token;

    address user = makeAddr("user");

    function setUp() external {
        token = new ERC20Mock();
        exchange = new UniswapV1Exchange(address(token), address(1), "Uniswap V1", "UNI-V1");
    }

    /////////////////////////
    //    getInputPrice    //
    /////////////////////////
    function testFuzz_GetInputPriceAlwaysMatchesAmmFormula(
        uint256 _inputAmount,
        uint256 _inputReserve,
        uint256 _outputReserve
    ) external view {
        // Bound values to uint112 because Uniswap reserves historically fit into uint112.
        // This also avoids unrealistic overflow scenarios during fuzzing.
        // _inputAmount, _inputReserve, and _outputReserve cannot be zero.
        _inputAmount = bound(_inputAmount, 1, type(uint112).max);
        _inputReserve = bound(_inputReserve, 1, type(uint112).max);
        _outputReserve = bound(_outputReserve, 1, type(uint112).max);

        uint256 inputAmountWithFee = _inputAmount * 997;
        uint256 expectedInputPrice =
            (inputAmountWithFee * _outputReserve) / ((_inputReserve * 1000) + inputAmountWithFee);

        uint256 actualInputPrice = exchange.getInputPrice(_inputAmount, _inputReserve, _outputReserve);

        assertEq(actualInputPrice, expectedInputPrice);
    }

    //////////////////////////
    //    getOutputPrice    //
    //////////////////////////
    function testFuzz_GetOutputPriceAlwaysMatchesAMMFormula(
        uint256 _outputAmount,
        uint256 _inputReserve,
        uint256 _outputReserve
    ) external view {
        // Bound values to uint112 because Uniswap reserves historically fit into uint112.
        // This also avoids unrealistic overflow scenarios during fuzzing.

        // _inputReserve, _outputReserve, and _outputAmount cannot be zero.

        _inputReserve = bound(_inputReserve, 1, type(uint112).max);

        // _outputReserve must be at least 2 so _outputAmount can be at least 1
        // while still keeping _outputAmount < _outputReserve.
        _outputReserve = bound(_outputReserve, 2, type(uint112).max);

        // _outputAmount must be lower than _outputReserve because the formula uses
        // _outputReserve - _outputAmount.
        _outputAmount = bound(_outputAmount, 1, _outputReserve - 1);

        uint256 numerator = _inputReserve * _outputAmount * 1000;
        uint256 denominator = (_outputReserve - _outputAmount) * 997;
        uint256 expectedOutputPrice = (numerator / denominator) + 1;

        uint256 actualOutputPrice = exchange.getOutputPrice(_outputAmount, _inputReserve, _outputReserve);

        assertEq(expectedOutputPrice, actualOutputPrice);
    }

    ////////////////////////
    //    addLiquidity    //
    ////////////////////////
    // Tests the invariant expectedLiquidity = (ethAmount * totalLiquidityBefore) / ethReserve;
    function testFuzz_AddLiquidityMintsCorrectLiquidity(uint256 _ethReserve, uint256 _tokenReserve, uint256 _ethAmount)
        external
    {
        // Reserves range from 1 ether to type(uint112).max to be realistic
        _ethReserve = bound(_ethReserve, 1 ether, type(uint112).max);
        _tokenReserve = bound(_tokenReserve, 1 ether, type(uint112).max);
        _ethAmount = bound(_ethAmount, 1 wei, type(uint112).max);

        // First LP
        deal(address(token), user, _tokenReserve);
        deal(user, _ethReserve);

        vm.startPrank(user);
        token.approve(address(exchange), _tokenReserve);

        exchange.addLiquidity{value: _ethReserve}(0, _tokenReserve, block.timestamp + 1);

        vm.stopPrank();

        uint256 totalLiquidityBefore = exchange.totalSupply();

        // Second LP
        address lp2 = makeAddr("lp2");

        uint256 requiredTokens = (_ethAmount * _tokenReserve) / _ethReserve + 1;

        deal(address(token), lp2, requiredTokens);
        deal(lp2, _ethAmount);

        vm.startPrank(lp2);

        token.approve(address(exchange), requiredTokens);

        uint256 liquidityMinted =
            exchange.addLiquidity{value: _ethAmount}(_ethAmount, requiredTokens, block.timestamp + 1);

        vm.stopPrank();

        uint256 expectedLiquidity = (_ethAmount * totalLiquidityBefore) / _ethReserve;

        assertEq(liquidityMinted, expectedLiquidity);

        uint256 totalLiquidityAfter = totalLiquidityBefore + liquidityMinted;
        uint256 totalLiquidityAfterExpected = _ethReserve + expectedLiquidity;
        assertEq(totalLiquidityAfter, totalLiquidityAfterExpected);
    }

    // Tests that addLiquidity preserves the ETH/token reserve ratio
    function testFuzz_AddLiquidityPreservesReserveRatio(uint256 _ethReserve, uint256 _tokenReserve, uint256 _ethAmount)
        external
    {
        // Reserves range from 1 ether to type(uint112).max to be realistic
        _ethReserve = bound(_ethReserve, 1 ether, type(uint112).max);
        _tokenReserve = bound(_tokenReserve, 1 ether, type(uint112).max);
        _ethAmount = bound(_ethAmount, 1 wei, type(uint112).max);

        // Setup initial liquidity
        deal(address(token), user, _tokenReserve);
        deal(user, _ethReserve);

        vm.startPrank(user);
        token.approve(address(exchange), _tokenReserve);

        exchange.addLiquidity{value: _ethReserve}(0, _tokenReserve, block.timestamp + 1);
        vm.stopPrank();

        uint256 tokenAmount = (uint256(_ethAmount) * _tokenReserve) / _ethReserve + 1;

        address lp2 = makeAddr("lp2");

        deal(address(token), lp2, tokenAmount);
        deal(lp2, _ethAmount);

        vm.startPrank(lp2);
        token.approve(address(exchange), tokenAmount);

        exchange.addLiquidity{value: _ethAmount}(1, tokenAmount, block.timestamp + 1);

        vm.stopPrank();

        uint256 newEthReserve = address(exchange).balance;
        uint256 newTokenReserve = token.balanceOf(address(exchange));

        assertApproxEqAbs((newEthReserve * 1e18) / newTokenReserve, (_ethReserve * 1e18) / _tokenReserve, 0.006 ether);
    }

    ///////////////////////////
    //    removeLiquidity    //
    ///////////////////////////
    // Invariants:
    //   - ethAmount = liquidityBurned * ethReserve / totalLiquidity
    //   - tokenAmount = liquidityBurned * tokenReserve / totalLiquidity
    function testFuzz_RemoveLiquidityReturnsProportionalReserves(
        uint256 _ethReserve,
        uint256 _tokenReserve,
        uint256 _liquidityToBurn
    ) external {
        _ethReserve = bound(_ethReserve, 1 ether, type(uint112).max);
        _tokenReserve = bound(_tokenReserve, 1 ether, type(uint112).max);
        _liquidityToBurn = bound(_liquidityToBurn, 1, _ethReserve);

        deal(address(token), user, _tokenReserve);
        deal(user, _ethReserve);

        vm.startPrank(user);
        token.approve(address(exchange), _tokenReserve);

        exchange.addLiquidity{value: _ethReserve}(0, _tokenReserve, block.timestamp + 1);

        uint256 totalLiquidity = exchange.totalSupply();

        uint256 expectedEthAmount = (_liquidityToBurn * _ethReserve) / totalLiquidity;

        uint256 expectedTokenAmount = (_liquidityToBurn * _tokenReserve) / totalLiquidity;

        if (expectedTokenAmount == 0) {
            vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientTokensWithdrawn.selector);
            exchange.removeLiquidity(_liquidityToBurn, 1, 1, block.timestamp + 1);
        } else {
            (uint256 ethAmount, uint256 tokenAmount) =
                exchange.removeLiquidity(_liquidityToBurn, 1, 1, block.timestamp + 1);

            assertEq(ethAmount, expectedEthAmount);
            assertEq(tokenAmount, expectedTokenAmount);
        }

        vm.stopPrank();
    }

    // Invariants:
    //  - totalSupply decreases by liquidityBurned
    //  - pool reserves decrease by the withdrawn amounts
    function testFuzz_RemoveLiquidityUpdatesReservesAndLpSupply(
        uint256 _ethReserve,
        uint256 _tokenReserve,
        uint256 _liquidityToBurn
    ) external {
        _ethReserve = bound(_ethReserve, 1 ether, type(uint112).max);
        _tokenReserve = bound(_tokenReserve, 1 ether, type(uint112).max);
        _liquidityToBurn = bound(_liquidityToBurn, 1, _ethReserve);

        deal(address(token), user, _tokenReserve);
        deal(user, _ethReserve);

        vm.startPrank(user);
        token.approve(address(exchange), _tokenReserve);

        exchange.addLiquidity{value: _ethReserve}(0, _tokenReserve, block.timestamp + 1);

        uint256 totalLiquidityBefore = exchange.totalSupply();

        uint256 expectedEthAmount = (_liquidityToBurn * _ethReserve) / totalLiquidityBefore;

        uint256 expectedTokenAmount = (_liquidityToBurn * _tokenReserve) / totalLiquidityBefore;

        if (expectedTokenAmount == 0) {
            vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientTokensWithdrawn.selector);
            exchange.removeLiquidity(_liquidityToBurn, 1, 1, block.timestamp + 1);
        } else {
            exchange.removeLiquidity(_liquidityToBurn, 1, 1, block.timestamp + 1);

            assertEq(exchange.totalSupply(), totalLiquidityBefore - _liquidityToBurn);
            assertEq(address(exchange).balance, _ethReserve - expectedEthAmount);
            assertEq(token.balanceOf(address(exchange)), _tokenReserve - expectedTokenAmount);
        }
        vm.stopPrank();
    }
}
