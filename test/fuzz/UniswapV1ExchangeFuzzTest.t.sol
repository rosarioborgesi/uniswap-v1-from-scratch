// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {UniswapV1Exchange} from "src/UniswapV1Exchange.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract UniswapV1ExchangeFuzzTest is Test {
    UniswapV1Exchange public exchange;
    ERC20Mock public token;

    address user = makeAddr("user");

    function setUp() external {
        token = new ERC20Mock();
        // mint tokens to user
        exchange = new UniswapV1Exchange(address(token));
    }

    //////////////////////////
    // getInputPrice Tests  //
    //////////////////////////
    function testGetInputPrice(uint256 _inputAmount, uint256 _inputReserve, uint256 _outputReserve) external view {
        _inputAmount = bound(_inputAmount, 1, type(uint112).max);
        _inputReserve = bound(_inputReserve, 1, type(uint112).max);
        _outputReserve = bound(_outputReserve, 1, type(uint112).max);

        uint256 inputAmountWithFee = _inputAmount * 997;
        uint256 expectedOutput = (inputAmountWithFee * _outputReserve) / ((_inputReserve * 1000) + inputAmountWithFee);

        uint256 actualOutput = exchange.getInputPrice(_inputAmount, _inputReserve, _outputReserve);

        assertEq(actualOutput, expectedOutput);
    }
}
