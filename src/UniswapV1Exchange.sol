// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

contract UniswapV1Exchange {
    ////////////////////////////////
    //            Errors          //
    ////////////////////////////////
    error UniswapV1Exchange__ZeroAddress();

    ////////////////////////////////
    //      State Variables       //
    ////////////////////////////////
    IERC20 private immutable i_token;

    constructor(address _tokenAddress) {
        if (_tokenAddress == address(0)) {
            revert UniswapV1Exchange__ZeroAddress();
        }
        i_token = IERC20(_tokenAddress);
    }

    //////////////////////////////////////////////////////
    //      External & Public View & Pure Functions     //
    //////////////////////////////////////////////////////
    function tokenAddress() external view returns (address) {
        return address(i_token);
    }
}
