// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {UniswapV1Exchange} from "src/UniswapV1Exchange.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

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
}
