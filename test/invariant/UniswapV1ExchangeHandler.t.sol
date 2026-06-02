// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {UniswapV1Exchange} from "src/UniswapV1Exchange.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract UniswapV1ExchangeHandler is Test {
    UniswapV1Exchange public exchange;
    ERC20Mock public token;
    uint256 public ghost_expectedEthReserve;
    uint256 public ghost_expectedTokenReserve;

    // Ghost Variables
    uint96 public constant MAX_TOKEN_AMOUNT = 10_000_000 ether;
    uint96 public constant MAX_ETH_AMOUNT = 10_000 ether;

    constructor(UniswapV1Exchange _exchange, ERC20Mock _token) {
        exchange = _exchange;
        token = _token;
    }

    function addLiquidity(uint256 _ethAmount, uint256 _maxTokens) external {
        _maxTokens = bound(_maxTokens, 1_000, MAX_TOKEN_AMOUNT);
        _ethAmount = bound(_ethAmount, 1e9, MAX_ETH_AMOUNT);

        uint256 totalLiquidity = exchange.totalSupply();

        uint256 tokensToDeposit;

        if (totalLiquidity == 0) {
            tokensToDeposit = _maxTokens;
        } else {
            uint256 ethReserve = address(exchange).balance;
            uint256 tokenReserve = token.balanceOf(address(exchange));

            tokensToDeposit = (_ethAmount * tokenReserve) / ethReserve + 1;

            if (tokensToDeposit > MAX_TOKEN_AMOUNT) {
                return;
            }
        }

        token.mint(address(this), tokensToDeposit);
        token.approve(address(exchange), tokensToDeposit);

        deal(address(this), _ethAmount);

        uint256 minLiquidity = totalLiquidity == 0 ? 0 : 1;

        exchange.addLiquidity{value: _ethAmount}(minLiquidity, tokensToDeposit, block.timestamp);

        ghost_expectedEthReserve += _ethAmount;
        ghost_expectedTokenReserve += tokensToDeposit;
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

        ghost_expectedEthReserve -= expectedEthAmount;
        ghost_expectedTokenReserve -= expectedTokenAmount;
    }

    receive() external payable {}
}
