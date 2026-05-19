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
    error UniswapV1Exchange__InputAmountIsZero();
    error UniswapV1Exchange__InsufficientReserves();
    error UniswapV1Exchange__EthSoldIsZero();
    error UniswapV1Exchange__DeadlineExpired();
    error UniswapV1Exchange__MinTokensIsZero();
    error UniswapV1Exchange__InsufficientOutputAmount();
    error UniswapV1Exchange__TokenTransferFailed(address recipient, uint256 tokensBought);
    error UniswapV1Exchange__InvalidRecipient();
    error UniswapV1Exchange__OutputAmountIsZero();
    error UniswapV1Exchange__OutputAmountGreaterOrEqualThanOutputReserve();
    error UniswapV1Exchange__TokensBoughtIsZero();
    error UniswapV1Exchange__MaxEthIsZero();
    error UniswapV1Exchange__EthSoldExceedsMaxEth();
    error UniswapV1Exchange__EthTransferFailed(address, recipient, uint256 amount);

    ////////////////////////////////
    //      State Variables       //
    ////////////////////////////////
    IERC20 private immutable i_token;

    ////////////////////////////////
    //           Events           //
    ////////////////////////////////
    event TokenPurchase(address indexed buyer, uint256 ethSold, uint256 tokensBought);

    ////////////////////////////////
    //          Functions         //
    ////////////////////////////////
    constructor(address _tokenAddress) {
        if (_tokenAddress == address(0)) {
            revert UniswapV1Exchange__ZeroAddress();
        }
        i_token = IERC20(_tokenAddress);
    }

    /**
     * @notice Convert ETH to Tokens.
     * @dev User specifies exact input (msg.value).
     * @dev User cannot specify minimum output or deadline.
     */
    receive() external payable {
        _ethToTokenInput(msg.value, 1, block.timestamp, msg.sender, msg.sender);
    }

    ////////////////////////////////
    //     External Functions     //
    ////////////////////////////////

    ////////////////////////////////
    //       Public Functions     //
    ////////////////////////////////
    /**
     * @notice Converts ETH to Tokens.
     * @dev User specifies exact input (msg.value) and minimum output.
     * @param _minTokens Minimum Tokens bought.
     * @param _deadline Time after which this transaction can no longer be executed.
     * @return Amount of Tokens bought
     */
    function ethToTokenSwapInput(uint256 _minTokens, uint256 _deadline) public payable returns (uint256) {
        return _ethToTokenInput(msg.value, _minTokens, _deadline, msg.sender, msg.sender);
    }

    /**
     * @notice Converts ETH to tokens and transfers tokens to recipient.
     * @dev User specifies exact ETH input with msg.value and minimum token output.
     * @param _minTokens Minimum amount of tokens bought.
     * @param _deadline Timestamp after which the transaction can no longer be executed.
     * @param _recipient Address receiving the output tokens.
     * @return Amount of tokens bought.
     */
    function ethToTokenTransferInput(uint256 _minTokens, uint256 _deadline, address _recipient)
        public
        payable
        returns (uint256)
    {
        if (_recipient == address(this) || _recipient == address(0)) {
            revert UniswapV1Exchange__InvalidRecipient();
        }
        return _ethToTokenInput(msg.value, _minTokens, _deadline, msg.sender, _recipient);
    }

    /////////////////////////////////
    //       Private Functions     //
    /////////////////////////////////

    //////////////////////////////////////////////////////
    //     Private & Internal View & Pure Functions     //
    //////////////////////////////////////////////////////
    /**
     * @notice Pricing function for converting between ETH and Tokens.
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
        if (_inputAmount == 0) {
            revert UniswapV1Exchange__InputAmountIsZero();
        }
        if (_inputReserve == 0 || _outputReserve == 0) {
            revert UniswapV1Exchange__InsufficientReserves();
        }

        uint256 inputAmountWithFee = _inputAmount * 997;
        uint256 numerator = inputAmountWithFee * _outputReserve;
        uint256 denominator = (_inputReserve * 1000) + inputAmountWithFee;
        return numerator / denominator;
    }

    /**
     * @dev Pricing function for converting between ETH and tokens.
     * @param _outputAmount Amount of ETH or tokens being bought.
     * @param _inputReserve Amount of input asset in exchange reserves.
     * @param _outputReserve Amount of output asset in exchange reserves.
     * @return Amount of input asset sold.
     */
    function _getOutputPrice(uint256 _outputAmount, uint256 _inputReserve, uint256 _outputReserve)
        private
        pure
        returns (uint256)
    {
        if (_outputAmount == 0) {
            revert UniswapV1Exchange__OutputAmountIsZero();
        }
        if (_inputReserve == 0 || _outputReserve == 0) {
            revert UniswapV1Exchange__InsufficientReserves();
        }

        if (_outputAmount >= _outputReserve) {
            revert UniswapV1Exchange__OutputAmountGreaterOrEqualThanOutputReserve();
        }

        uint256 numerator = _inputReserve * _outputAmount * 1000;
        uint256 denominator = (_outputReserve - _outputAmount) * 997;

        return (numerator / denominator) + 1;
    }

    /**
     * @notice Executes an ETH to token swap.
     * @param _ethSold Amount of ETH sold.
     * @param _minTokens Minimum amount of tokens bought.
     * @param _deadline Swap deadline timestamp.
     * @param _buyer Address paying ETH.
     * @param _recipient Address receiving tokens.
     * @return Amount of tokens bought.
     */
    function _ethToTokenInput(
        uint256 _ethSold,
        uint256 _minTokens,
        uint256 _deadline,
        address _buyer,
        address _recipient
    ) private returns (uint256) {
        if (block.timestamp > _deadline) {
            revert UniswapV1Exchange__DeadlineExpired();
        }
        if (_ethSold == 0) {
            revert UniswapV1Exchange__EthSoldIsZero();
        }
        if (_minTokens == 0) {
            revert UniswapV1Exchange__MinTokensIsZero();
        }

        uint256 tokenReserve = i_token.balanceOf(address(this));
        uint256 ethReserveBeforeSwap = address(this).balance - _ethSold;

        uint256 tokensBought = _getInputPrice(_ethSold, ethReserveBeforeSwap, tokenReserve);

        // Slippage protection
        if (tokensBought < _minTokens) {
            revert UniswapV1Exchange__InsufficientOutputAmount();
        }

        bool success = i_token.transfer(_recipient, tokensBought);
        if (!success) {
            revert UniswapV1Exchange__TokenTransferFailed(_recipient, tokensBought);
        }

        emit TokenPurchase(_buyer, _ethSold, tokensBought);

        return tokensBought;
    }

    /**
     * @notice Converts ETH to an exact amount of tokens.
     * @dev User specifies the exact token output and maximum ETH input.
     * @param _tokensBought Amount of tokens bought.
     * @param _maxEth Maximum amount of ETH sold.
     * @param _deadline Timestamp after which the transaction can no longer be executed.
     * @param _buyer Address paying ETH.
     * @param _recipient Address receiving tokens.
     * @return Amount of ETH sold.
     */
    function _ethToTokenOutput(
        uint256 _tokensBought,
        uint256 _maxEth,
        uint256 _deadline,
        address _buyer,
        address _recipient
    ) private returns (uint256) {
        if (_deadline < block.timestamp) {
            revert UniswapV1Exchange__DeadlineExpired();
        }
        if (_tokensBought == 0) {
            revert UniswapV1Exchange__TokensBoughtIsZero();
        }
        if (_maxEth == 0) {
            revert UniswapV1Exchange__MaxEthIsZero();
        }

        uint256 tokenReserve = i_token.balanceOf(address(this));
        uint256 ethReserve = address(this).balance - _maxEth;

        uint256 ethSold = _getOutputPrice(_tokensBought, ethReserve, tokenReserve);

        // Slippage protection
        if (ethSold > _maxEth) {
            revert UniswapV1Exchange__EthSoldExceedsMaxEth();
        }

        uint256 ethRefund = _maxEth - ethSold;

        if (ethRefund > 0) {
            (bool ethTransferSuccess,) = _buyer.call{value: ethRefund}("");
            if (!ethTransferSuccess) {
                revert UniswapV1Exchange__EthTransferFailed(_buyer, ethRefund);
            }
        }

        bool tokenTransferSuccess = i_token.transfer(_recipient, _tokensBought);
        if (!tokenTransferSuccess) {
            revert UniswapV1Exchange__TokenTransferFailed(_recipient, _tokensBought);
        }

        emit TokenPurchase(_buyer, ethSold, _tokensBought);

        return ethSold;
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

    /**
     * @notice Returns how many tokens are bought for an exact ETH input.
     * @param _ethSold Amount of ETH sold.
     * @return Amount of tokens bought.
     */
    function getEthToTokenInputPrice(uint256 _ethSold) external view returns (uint256) {
        if (_ethSold == 0) {
            revert UniswapV1Exchange__EthSoldIsZero();
        }
        uint256 ethReserve = address(this).balance;
        uint256 tokenReserve = i_token.balanceOf(address(this));

        return _getInputPrice(_ethSold, ethReserve, tokenReserve);
    }

    function getOutputPrice(uint256 _outputAmount, uint256 _inputReserve, uint256 _outputReserve)
        external
        pure
        returns (uint256)
    {
        return _getOutputPrice(_outputAmount, _inputReserve, _outputReserve);
    }
}
