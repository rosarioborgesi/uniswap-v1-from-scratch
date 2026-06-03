// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {UniswapV1Exchange} from "src/UniswapV1Exchange.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract UniswapV1ExchangeHandler is Test {
    UniswapV1Exchange public exchange;
    ERC20Mock public token;

    uint256 public ghost_ethDeposited;
    uint256 public ghost_tokensDeposited;
    uint256 public ghost_ethWithdrawn;
    uint256 public ghost_tokensWithdrawn;

    constructor(UniswapV1Exchange _exchange, ERC20Mock _token) {
        exchange = _exchange;
        token = _token;
    }

    // Covers both addLiquidity paths:
    // - initial liquidity when totalLiquidity == 0
    // - proportional liquidity when totalLiquidity > 0
    function addLiquidity(uint256 _ethAmount, uint256 _maxTokens) external {
        uint256 handlerEthBalance = address(this).balance;
        uint256 handlerTokenBalance = token.balanceOf(address(this));

        if (handlerEthBalance == 0 || handlerTokenBalance == 0) {
            return;
        }

        _ethAmount = bound(_ethAmount, 1, handlerEthBalance);

        uint256 totalLiquidity = exchange.totalSupply();

        uint256 tokensToDeposit;
        uint256 minLiquidity;

        if (totalLiquidity == 0) {
            if (_ethAmount < 1e9) {
                return;
            }
            _maxTokens = bound(_maxTokens, 1, handlerTokenBalance);
            tokensToDeposit = _maxTokens;
            minLiquidity = 0;
        } else {
            uint256 ethReserve = address(exchange).balance;
            uint256 tokenReserve = token.balanceOf(address(exchange));

            tokensToDeposit = (_ethAmount * tokenReserve) / ethReserve + 1;

            if (tokensToDeposit > handlerTokenBalance) {
                return;
            }
            uint256 liquidityMinted = (_ethAmount * totalLiquidity) / ethReserve;

            if (liquidityMinted == 0) {
                return;
            }

            minLiquidity = 1;
        }

        token.approve(address(exchange), tokensToDeposit);

        exchange.addLiquidity{value: _ethAmount}(minLiquidity, tokensToDeposit, block.timestamp);

        ghost_ethDeposited += _ethAmount;
        ghost_tokensDeposited += tokensToDeposit;
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

        ghost_ethWithdrawn += expectedEthAmount;
        ghost_tokensWithdrawn += expectedTokenAmount;
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

        ghost_ethDeposited += _ethSold;
        ghost_tokensWithdrawn += tokensBought;
    }

    function tokenToEthSwapInput(uint256 _tokensSold) external {
        uint256 ethReserve = address(exchange).balance;
        uint256 tokenReserve = token.balanceOf(address(exchange));

        // The pool must be initialized before pricing works.
        if (ethReserve == 0 || tokenReserve == 0) {
            return;
        }

        uint256 handlerTokenBalance = token.balanceOf(address(this));

        if (handlerTokenBalance == 0) {
            return;
        }

        _tokensSold = bound(_tokensSold, 1, handlerTokenBalance);

        uint256 ethBought = exchange.getTokenToEthInputPrice(_tokensSold);

        // If the output rounds down to zero, the swap would fail because minEth = 1.
        if (ethBought == 0) {
            return;
        }

        token.approve(address(exchange), _tokensSold);

        exchange.tokenToEthSwapInput(_tokensSold, 1, block.timestamp);

        ghost_tokensDeposited += _tokensSold;
        ghost_ethWithdrawn += ethBought;
    }

    function ethToTokenViaReceive(uint256 _ethSold) public {
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

        (bool success,) = address(exchange).call{value: _ethSold}("");
        require(success, "receive call failed");

        ghost_ethDeposited += _ethSold;
        ghost_tokensWithdrawn += tokensBought;
    }

    receive() external payable {}
}
