// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {UniswapV1Exchange} from "src/UniswapV1Exchange.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract UniswapV1ExchangeSwapHandler is Test {
    UniswapV1Exchange public exchange;
    ERC20Mock public token;

    constructor(UniswapV1Exchange _exchange, ERC20Mock _token) {
        exchange = _exchange;
        token = _token;
    }

    function ethToTokenSwapInput(uint256 _ethSold) external {
        uint256 ethReserve = address(exchange).balance;
        uint256 tokenReserve = token.balanceOf(address(exchange));

        if (ethReserve == 0 || tokenReserve == 0) {
            return;
        }

        uint256 handlerEthBalance = address(this).balance;

        if (handlerEthBalance == 0) {
            return;
        }

        _ethSold = bound(_ethSold, 1, handlerEthBalance);

        uint256 tokensBought = exchange.getEthToTokenInputPrice(_ethSold);

        if (tokensBought == 0) {
            return;
        }

        exchange.ethToTokenSwapInput{value: _ethSold}(1, block.timestamp);
    }

    function tokenToEthSwapInput(uint256 _tokensSold) external {
        uint256 ethReserve = address(exchange).balance;
        uint256 tokenReserve = token.balanceOf(address(exchange));

        if (ethReserve == 0 || tokenReserve == 0) {
            return;
        }

        uint256 handlerTokenBalance = token.balanceOf(address(this));

        if (handlerTokenBalance == 0) {
            return;
        }

        _tokensSold = bound(_tokensSold, 1, handlerTokenBalance);

        uint256 ethBought = exchange.getTokenToEthInputPrice(_tokensSold);

        if (ethBought == 0) {
            return;
        }

        token.approve(address(exchange), _tokensSold);

        exchange.tokenToEthSwapInput(_tokensSold, 1, block.timestamp);
    }

    receive() external payable {}
}
