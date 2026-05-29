// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {UniswapV1Exchange} from "src/UniswapV1Exchange.sol";
import {Constants} from "./Constants.sol";
import {TestToken} from "./TestToken.sol";

contract UniswapV1ExchangeIntegrationTest is Test, Constants {
    UniswapV1Exchange public exchange;
    TestToken public hayToken;

    address user = makeAddr("user");

    function setUp() external {
        hayToken = new TestToken("HAY Token", "Hay", HAY_TOKEN_SUPPLY);
        exchange = new UniswapV1Exchange(address(hayToken), address(1), "Uniswap V1", "UNI-V1");
    }

    ///////////////////////////////
    //    ethToTokenSwapInput    //
    ///////////////////////////////

    /**
     * @notice Tests a successful ETH to token swap.
     */
    /* function testSwapInput() external {
        uint256 hayPurchased = exchange.getInputPrice(ETH_SOLD, ETH_RESERVE, HAY_RESERVE);
        assertEq(exchange.getEthToTokenInputPrice(ETH_SOLD), hayPurchased);

        // eth sold == 0
    } */
}
