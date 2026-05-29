// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

abstract contract Constants {
    address public constant ZERO_ADDR = address(0);
    // PASSING DEADLINE
    uint256 public constant DEADLINE = 1742680400;
    // INITIAL TOKEN SUPPLIES
    uint256 public constant HAY_TOKEN_SUPPLY = 10_0000 ether;
    // INITIAL RESERVE SIZE
    uint256 public constant ETH_RESERVE = 5 ether;
    uint256 public constant HAY_RESERVE = 10 ether;
    // ETH to ERC20 swap input
    uint256 public constant ETH_SOLD = 1 ether;
    uint256 public constant MIN_HAY_BOUGHT = 1;
}

/* ZERO_ADDR = '0x0000000000000000000000000000000000000000'
# Initial ETH balance of buyer
INITIAL_ETH = 1*10**24
# Passing deadline
DEADLINE = 1742680400 # deadline = w3.eth.getBlock(w3.eth.blockNumber).timestamp
# INITIAL RESERVE SIZE
ETH_RESERVE = 5*10**18
HAY_RESERVE = 10*10**18
DEN_RESERVE = 20*10**18
# ETH to ERC20 swap input
ETH_SOLD = 1*10**18
MIN_HAY_BOUGHT = 1
# ETH to ERC20 swap output
HAY_BOUGHT = 1662497915624478906
MAX_ETH_SOLD = 2*10**18
# ERC20 to ETH swap input
HAY_SOLD = 2*10**18
MIN_ETH_BOUGHT = 1
# ERC20 to ETH swap output
ETH_BOUGHT = 831248957812239453
MAX_HAY_SOLD = 3*10**18
# ERC20 to ERC20
MIN_DEN_BOUGHT = 1
DEN_BOUGHT = 2843678215834080602 */