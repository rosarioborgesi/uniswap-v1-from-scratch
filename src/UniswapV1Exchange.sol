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
    error UniswapV1Exchange__InsufficientReserves();

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
    //     Private & Internal View & Pure Functions     //
    //////////////////////////////////////////////////////
    /**
     * @notice Calculates output amount for an exact input swap.
     * @param _inputAmount Amount of input asset sold.
     * @param _inputReserve Reserve of input asset.
     * @param _outputReserve Reserve of output asset.
     * @return Amount of output asset bought.
     */
    function _getInputPrice(uint256 _inputAmount, uint256 _inputReserve, uint256 _outputReserve)
        private
        pure
        returns (uint256)
    {
        if (_inputReserve == 0 || _outputReserve == 0) {
            revert UniswapV1Exchange__InsufficientReserves();
        }

        uint256 inputAmountWithFee = _inputAmount * 997;
        uint256 numerator = inputAmountWithFee * _outputReserve;
        uint256 denominator = (_inputReserve * 1000) + inputAmountWithFee;

        return numerator / denominator;
    }

    //////////////////////////////////////////////////////
    //      External & Public View & Pure Functions     //
    //////////////////////////////////////////////////////
    function tokenAddress() external view returns (address) {
        return address(i_token);
    }

    function getInputPrice(uint256 _inputAmount, uint256 _inputReserve, uint256 _outputReserve)
        external
        pure
        returns (uint256)
    {
        return _getInputPrice(_inputAmount, _inputReserve, _outputReserve);
    }
}
