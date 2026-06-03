// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {UniswapV1Exchange} from "src/UniswapV1Exchange.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract UniswapV1ExchangeLiquidityHandler is Test {
    UniswapV1Exchange public exchange;
    ERC20Mock public token;

    constructor(UniswapV1Exchange _exchange, ERC20Mock _token) {
        exchange = _exchange;
        token = _token;
    }

    // Fuzzes only proportional liquidity additions.
    // The pool is already initialized in setUp(), so this always tests
    // the totalLiquidity > 0 branch.
    function addLiquidity(uint256 _ethAmount) external {
        uint256 handlerEthBalance = address(this).balance;
        uint256 handlerTokenBalance = token.balanceOf(address(this));

        if (handlerEthBalance == 0 || handlerTokenBalance == 0) {
            return;
        }

        _ethAmount = bound(_ethAmount, 1, handlerEthBalance);

        uint256 totalLiquidity = exchange.totalSupply();
        uint256 ethReserve = address(exchange).balance;
        uint256 tokenReserve = token.balanceOf(address(exchange));

        if (totalLiquidity == 0 || ethReserve == 0 || tokenReserve == 0) {
            return;
        }

        uint256 tokensToDeposit = (_ethAmount * tokenReserve) / ethReserve + 1;

        if (tokensToDeposit > handlerTokenBalance) {
            return;
        }

        uint256 liquidityMinted = (_ethAmount * totalLiquidity) / ethReserve;

        if (liquidityMinted == 0) {
            return;
        }

        token.approve(address(exchange), tokensToDeposit);

        exchange.addLiquidity{value: _ethAmount}(1, tokensToDeposit, block.timestamp);
    }

    function removeLiquidity(uint256 _liquidityAmount) external {
        uint256 lpBalance = exchange.balanceOf(address(this));
        uint256 totalLiquidity = exchange.totalSupply();

        if (lpBalance == 0 || totalLiquidity == 0) {
            return;
        }

        _liquidityAmount = bound(_liquidityAmount, 1, lpBalance);

        uint256 ethReserve = address(exchange).balance;
        uint256 tokenReserve = token.balanceOf(address(exchange));

        uint256 expectedEthAmount = (_liquidityAmount * ethReserve) / totalLiquidity;
        uint256 expectedTokenAmount = (_liquidityAmount * tokenReserve) / totalLiquidity;

        if (expectedEthAmount == 0 || expectedTokenAmount == 0) {
            return;
        }

        exchange.removeLiquidity(_liquidityAmount, 1, 1, block.timestamp);
    }

    receive() external payable {}
}
