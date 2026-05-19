// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {UniswapV1Exchange} from "src/UniswapV1Exchange.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract UniswapV1ExchangeFuzzTest is Test {
    UniswapV1Exchange public exchange;
    ERC20Mock public token;

    function setUp() external {
        token = new ERC20Mock();
        exchange = new UniswapV1Exchange(address(token));
    }

    /////////////////////////
    //    getInputPrice    //
    /////////////////////////
    function testGetInputPriceAlwaysMatchesAmmFormula(
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
    function testGetOutputPriceAlwaysMatchesAMMFormula(
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
}
