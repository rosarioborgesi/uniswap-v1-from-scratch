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

import {ERC20, IERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

interface IUniswapV1Factory {
    function getExchange(address _token) external view returns (address);
}

contract UniswapV1Exchange is ERC20 {
    ////////////////////////////////
    //            Errors          //
    ////////////////////////////////
    error UniswapV1Exchange__TokenAddressIsZero();
    error UniswapV1Exchange__InputAmountIsZero();
    error UniswapV1Exchange__InsufficientReserves();
    error UniswapV1Exchange__EthSoldIsZero();
    error UniswapV1Exchange__DeadlineExpired();
    error UniswapV1Exchange__MinTokensIsZero();
    error UniswapV1Exchange__InsufficientTokensBought();
    error UniswapV1Exchange__TokenTransferFailed(address sender, address recipient, uint256 tokensBought);
    error UniswapV1Exchange__InvalidRecipient();
    error UniswapV1Exchange__OutputAmountIsZero();
    error UniswapV1Exchange__OutputAmountGreaterOrEqualThanOutputReserve();
    error UniswapV1Exchange__TokensBoughtIsZero();
    error UniswapV1Exchange__MaxEthIsZero();
    error UniswapV1Exchange__EthSoldExceedsMaxEth();
    error UniswapV1Exchange__EthTransferFailed(address recipient, uint256 amount);
    error UniswapV1Exchange__MaxTokensIsZero();
    error UniswapV1Exchange__InsufficientEthAmount();
    error UniswapV1Exchange__MinLiquidityIsZero();
    error UniswapV1Exchange__MaxTokensExceeded();
    error UniswapV1Exchange__InsufficientLiquidityMinted();
    error UniswapV1Exchange__AmountIsZero();
    error UniswapV1Exchange__MinEthIsZero();
    error UniswapV1Exchange__TotalLiquidityIsZero();
    error UniswapV1Exchange__InsufficientEthWithdrawn();
    error UniswapV1Exchange__InsufficientTokensWithdrawn();
    error UniswapV1Exchange__TokensSoldIsZero();
    error UniswapV1Exchange__EthBoughtExceedsMinEth();
    error UniswapV1Exchange__EthBoughtIsZero();
    error UniswapV1Exchange__TokensSoldExceedsMaxTokens();
    error UniswapV1Exchange__EmptyLpTokenName();
    error UniswapV1Exchange__EmptyLpTokenSymbol();
    error UniswapV1Exchange__MinTokensBoughtIsZero();
    error UniswapV1Exchange__MinEthBoughtIsZero();
    error UniswapV1Exchange__InvalidExchange();
    error UniswapV1Exchange__InsufficientEthBought();
    error UniswapV1Exchange__FactoryAddressIsZero();

    ////////////////////////////////
    //      State Variables       //
    ////////////////////////////////
    IERC20 private immutable i_token;
    IUniswapV1Factory private immutable i_factory;

    ////////////////////////////////
    //           Events           //
    ////////////////////////////////
    event TokenPurchase(address indexed buyer, uint256 ethSold, uint256 tokensBought);
    event EthPurchase(address indexed buyer, uint256 tokenSold, uint256 ethBought);
    event AddLiquidity(address indexed provider, uint256 ethAmount, uint256 tokenAmount);
    event RemoveLiquidity(address indexed provider, uint256 ethAmount, uint256 tokenAmount);

    ////////////////////////////////
    //          Functions         //
    ////////////////////////////////
    constructor(address _tokenAddr, address _factoryAddr, string memory _lpTokenName, string memory _lpTokensSymbol)
        ERC20(_lpTokenName, _lpTokensSymbol)
    {
        if (_tokenAddr == address(0)) {
            revert UniswapV1Exchange__TokenAddressIsZero();
        }
        if (bytes(_lpTokenName).length == 0) {
            revert UniswapV1Exchange__EmptyLpTokenName();
        }
        if (bytes(_lpTokensSymbol).length == 0) {
            revert UniswapV1Exchange__EmptyLpTokenSymbol();
        }

        if (_factoryAddr == address(0)) {
            revert UniswapV1Exchange__FactoryAddressIsZero();
        }

        i_token = IERC20(_tokenAddr);
        i_factory = IUniswapV1Factory(_factoryAddr);
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
    /**
     * @notice Deposits ETH and tokens into the pool and mints LP tokens.
     * @dev If liquidity already exists, tokens are deposited at the current pool ratio.
     *      If this is the first deposit, `_maxTokens` is used as the initial token amount.
     * @param _minLiquidity Minimum amount of LP tokens the caller is willing to receive.
     * @param _maxTokens Maximum amount of tokens the caller is willing to deposit.
     * @param _deadline Timestamp after which the transaction is no longer valid.
     * @return Amount of LP tokens minted to the caller.
     */
    function addLiquidity(uint256 _minLiquidity, uint256 _maxTokens, uint256 _deadline)
        external
        payable
        returns (uint256)
    {
        if (_deadline <= block.timestamp) {
            revert UniswapV1Exchange__DeadlineExpired();
        }
        if (_maxTokens == 0) {
            revert UniswapV1Exchange__MaxTokensIsZero();
        }
        if (msg.value == 0) {
            revert UniswapV1Exchange__InsufficientEthAmount();
        }

        uint256 totalLiquidity = totalSupply();

        if (totalLiquidity > 0) {
            if (_minLiquidity == 0) {
                revert UniswapV1Exchange__MinLiquidityIsZero();
            }
            uint256 ethReserve = address(this).balance - msg.value;
            uint256 tokenReserve = i_token.balanceOf(address(this));

            uint256 tokenAmount = msg.value * tokenReserve / ethReserve + 1;

            uint256 liquidityMinted = msg.value * totalLiquidity / ethReserve;

            if (_maxTokens < tokenAmount) {
                revert UniswapV1Exchange__MaxTokensExceeded();
            }
            if (liquidityMinted < _minLiquidity) {
                revert UniswapV1Exchange__InsufficientLiquidityMinted();
            }

            _mint(msg.sender, liquidityMinted);

            bool success = i_token.transferFrom(msg.sender, address(this), tokenAmount);
            if (!success) {
                revert UniswapV1Exchange__TokenTransferFailed(msg.sender, address(this), tokenAmount);
            }

            emit AddLiquidity(msg.sender, msg.value, tokenAmount);

            return liquidityMinted;
        } else {
            if (msg.value < 1_000_000_000) {
                revert UniswapV1Exchange__InsufficientEthAmount();
            }
            uint256 tokenAmount = _maxTokens;
            uint256 initialLiquidity = address(this).balance;

            _mint(msg.sender, initialLiquidity);

            bool success = i_token.transferFrom(msg.sender, address(this), tokenAmount);
            if (!success) {
                revert UniswapV1Exchange__TokenTransferFailed(msg.sender, address(this), tokenAmount);
            }

            emit AddLiquidity(msg.sender, msg.value, tokenAmount);

            return initialLiquidity;
        }
    }

    /**
     * @notice Burns LP tokens and withdraws the caller's proportional share of ETH and tokens.
     * @dev Calculates ETH and token amounts based on the caller's LP token share over total liquidity.
     *      Reverts if the deadline expired or if the withdrawn amounts are lower than the minimums.
     * @param _amount Amount of LP tokens to burn.
     * @param _minEth Minimum amount of ETH the caller is willing to receive.
     * @param _minTokens Minimum amount of tokens the caller is willing to receive.
     * @param _deadline Timestamp after which the transaction is no longer valid.
     * @return ethAmount Amount of ETH withdrawn.
     * @return tokenAmount Amount of tokens withdrawn.
     */
    function removeLiquidity(uint256 _amount, uint256 _minEth, uint256 _minTokens, uint256 _deadline)
        external
        returns (uint256 ethAmount, uint256 tokenAmount)
    {
        if (_amount == 0) {
            revert UniswapV1Exchange__AmountIsZero();
        }

        if (_deadline <= block.timestamp) {
            revert UniswapV1Exchange__DeadlineExpired();
        }

        if (_minEth == 0) {
            revert UniswapV1Exchange__MinEthIsZero();
        }

        if (_minTokens == 0) {
            revert UniswapV1Exchange__MinTokensIsZero();
        }

        uint256 totalLiquidity = totalSupply();

        if (totalLiquidity == 0) {
            revert UniswapV1Exchange__TotalLiquidityIsZero();
        }

        uint256 ethReserve = address(this).balance;
        uint256 tokenReserve = i_token.balanceOf(address(this));

        ethAmount = (_amount * ethReserve) / totalLiquidity;
        tokenAmount = (_amount * tokenReserve) / totalLiquidity;

        if (_minEth > ethAmount) {
            revert UniswapV1Exchange__InsufficientEthWithdrawn();
        }

        if (_minTokens > tokenAmount) {
            revert UniswapV1Exchange__InsufficientTokensWithdrawn();
        }

        _burn(msg.sender, _amount);

        (bool ethSent,) = msg.sender.call{value: ethAmount}("");
        if (!ethSent) {
            revert UniswapV1Exchange__EthTransferFailed(msg.sender, ethAmount);
        }

        bool tokenSent = i_token.transfer(msg.sender, tokenAmount);
        if (!tokenSent) {
            revert UniswapV1Exchange__TokenTransferFailed(address(this), msg.sender, tokenAmount);
        }

        emit RemoveLiquidity(msg.sender, ethAmount, tokenAmount);

        return (ethAmount, tokenAmount);
    }

    /**
     * @notice Converts ETH to Tokens.
     * @dev User specifies exact input (msg.value) and minimum output.
     * @param _minTokens Minimum Tokens bought.
     * @param _deadline Time after which this transaction can no longer be executed.
     * @return Amount of Tokens bought
     */
    function ethToTokenSwapInput(uint256 _minTokens, uint256 _deadline) external payable returns (uint256) {
        return _ethToTokenInput(msg.value, _minTokens, _deadline, msg.sender, msg.sender);
    }

    /**
     * @notice Converts ETH to an exact amount of tokens.
     * @dev User specifies maximum ETH input with msg.value and exact token output.
     * @param _tokensBought Amount of tokens bought.
     * @param _deadline Timestamp after which the transaction can no longer be executed.
     * @return Amount of ETH sold.
     */
    function ethToTokenSwapOutput(uint256 _tokensBought, uint256 _deadline) public payable returns (uint256) {
        return _ethToTokenOutput(_tokensBought, msg.value, _deadline, msg.sender, msg.sender);
    }

    /**
     * @notice Swaps an exact amount of tokens for ETH.
     * @dev The caller sells `_tokensSold` tokens and receives ETH directly.
     * @param _tokensSold Amount of tokens sold by the caller.
     * @param _minEth Minimum amount of ETH the caller is willing to receive.
     * @param _deadline Timestamp after which the transaction is no longer valid.
     * @return Amount of ETH bought by the caller.
     */
    function tokenToEthSwapInput(uint256 _tokensSold, uint256 _minEth, uint256 _deadline) external returns (uint256) {
        return _tokenToEthInput(_tokensSold, _minEth, _deadline, msg.sender, msg.sender);
    }

    /**
     * @notice Swaps an exact amount of tokens for ETH and sends the ETH to a recipient.
     * @dev The caller sells `_tokensSold` tokens, while `_recipient` receives the ETH.
     * @param _tokensSold Amount of tokens sold by the caller.
     * @param _minEth Minimum amount of ETH the caller is willing the recipient to receive.
     * @param _deadline Timestamp after which the transaction is no longer valid.
     * @param _recipient Address receiving the ETH bought.
     * @return Amount of ETH sent to the recipient.
     */
    function tokenToEthTransferInput(uint256 _tokensSold, uint256 _minEth, uint256 _deadline, address _recipient)
        external
        returns (uint256)
    {
        if (_recipient == address(this) || _recipient == address(0)) {
            revert UniswapV1Exchange__InvalidRecipient();
        }
        return _tokenToEthInput(_tokensSold, _minEth, _deadline, msg.sender, _recipient);
    }

    /**
     * @notice Swaps tokens for an exact amount of ETH.
     * @dev The caller specifies the exact ETH output desired and the maximum
     *      amount of tokens willing to sell.
     * @param _ethBought Exact amount of ETH the caller wants to receive.
     * @param _maxTokens Maximum amount of tokens the caller is willing to sell.
     * @param _deadline Timestamp after which the transaction is no longer valid.
     * @return Amount of tokens sold by the caller.
     */
    function tokenToEthSwapOutput(uint256 _ethBought, uint256 _maxTokens, uint256 _deadline)
        external
        returns (uint256)
    {
        return _tokenToEthOutput(_ethBought, _maxTokens, _deadline, msg.sender, msg.sender);
    }

    /**
     * @notice Swaps tokens for an exact amount of ETH and sends the ETH to a recipient.
     * @dev The caller specifies the exact ETH output desired and the maximum
     *      amount of tokens willing to sell.
     * @param _ethBought Exact amount of ETH the recipient will receive.
     * @param _maxTokens Maximum amount of tokens the caller is willing to sell.
     * @param _deadline Timestamp after which the transaction is no longer valid.
     * @param _recipient Address receiving the ETH bought.
     * @return Amount of tokens sold by the caller.
     */
    function tokenToEthTransferOutput(uint256 _ethBought, uint256 _maxTokens, uint256 _deadline, address _recipient)
        external
        returns (uint256)
    {
        if (_recipient == address(this) || _recipient == address(0)) {
            revert UniswapV1Exchange__InvalidRecipient();
        }
        return _tokenToEthOutput(_ethBought, _maxTokens, _deadline, msg.sender, _recipient);
    }

    /**
     * @notice Swaps an exact amount of this exchange token for another ERC20 token.
     * @dev The swap is routed through ETH: Token A -> ETH -> Token B.
     *      The destination exchange is found through the factory using `_tokenAddr`.
     * @param _tokensSold Exact amount of this exchange token sold by the caller.
     * @param _minTokensBought Minimum amount of output tokens the caller is willing to receive.
     * @param _minEthBought Minimum amount of intermediate ETH that must be bought.
     * @param _deadline Timestamp after which the transaction is no longer valid.
     * @param _tokenAddr Address of the ERC20 token being bought.
     * @return tokensBought Amount of output tokens bought by the caller.
     */
    function tokenToTokenSwapInput(
        uint256 _tokensSold,
        uint256 _minTokensBought,
        uint256 _minEthBought,
        uint256 _deadline,
        address _tokenAddr
    ) external returns (uint256) {
        address exchangeAddr = i_factory.getExchange(_tokenAddr);
        return _tokenToTokenInput(
            _tokensSold, _minTokensBought, _minEthBought, _deadline, msg.sender, msg.sender, payable(exchangeAddr)
        );
    }

    /**
     * @notice Swaps an exact amount of this exchange token for another ERC20 token and sends it to a recipient.
     * @dev The swap is routed through ETH: Token A -> ETH -> Token B.
     *      The destination exchange is found through the factory using `_tokenAddr`.
     * @param _tokensSold Exact amount of this exchange token sold by the caller.
     * @param _minTokensBought Minimum amount of output tokens the recipient is willing to receive.
     * @param _minEthBought Minimum amount of intermediate ETH that must be bought.
     * @param _deadline Timestamp after which the transaction is no longer valid.
     * @param _recipient Address receiving the output tokens.
     * @param _tokenAddr Address of the ERC20 token being bought.
     * @return tokensBought Amount of output tokens bought for the recipient.
     */
    function tokenToTokenTransferInput(
        uint256 _tokensSold,
        uint256 _minTokensBought,
        uint256 _minEthBought,
        uint256 _deadline,
        address _recipient,
        address _tokenAddr
    ) external returns (uint256) {
        if (_recipient == address(0) || _recipient == address(this)) {
            revert UniswapV1Exchange__InvalidRecipient();
        }
        address exchangeAddr = i_factory.getExchange(_tokenAddr);
        return _tokenToTokenInput(
            _tokensSold, _minTokensBought, _minEthBought, _deadline, msg.sender, _recipient, payable(exchangeAddr)
        );
    }

    ////////////////////////////////
    //       Public Functions     //
    ////////////////////////////////

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

    /**
     * @notice Converts ETH to an exact amount of tokens and transfers tokens to recipient.
     * @dev User specifies maximum ETH input with msg.value and exact token output.
     * @param _tokensBought Amount of tokens bought.
     * @param _deadline Timestamp after which the transaction can no longer be executed.
     * @param _recipient Address receiving output tokens.
     * @return Amount of ETH sold.
     */
    function ethToTokenTransferOutput(uint256 _tokensBought, uint256 _deadline, address _recipient)
        public
        payable
        returns (uint256)
    {
        if (_recipient == address(this) || _recipient == address(0)) {
            revert UniswapV1Exchange__InvalidRecipient();
        }
        return _ethToTokenOutput(_tokensBought, msg.value, _deadline, msg.sender, _recipient);
    }

    /////////////////////////////////
    //       Private Functions     //
    /////////////////////////////////

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
        uint256 ethReserve = address(this).balance - _ethSold;

        uint256 tokensBought = _getInputPrice(_ethSold, ethReserve, tokenReserve);

        if (tokensBought < _minTokens) {
            revert UniswapV1Exchange__InsufficientTokensBought();
        }

        bool success = i_token.transfer(_recipient, tokensBought);
        if (!success) {
            revert UniswapV1Exchange__TokenTransferFailed(address(this), _recipient, tokensBought);
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
        // msg.value is already included in address(this).balance.
        // Since _maxEth = msg.value, subtracting _maxEth gives the ETH reserve
        // before the swap and can never underflow.
        uint256 ethReserve = address(this).balance - _maxEth;
        // _getOutputPrice requires _tokensBought < tokenReserve,
        // so the exchange cannot sell more tokens than it owns.
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
            revert UniswapV1Exchange__TokenTransferFailed(address(this), _recipient, _tokensBought);
        }

        emit TokenPurchase(_buyer, ethSold, _tokensBought);

        return ethSold;
    }

    /**
     * @notice Swaps an exact amount of tokens for ETH.
     * @dev Shared internal logic used by tokenToEthSwapInput and tokenToEthTransferInput.
     *      Calculates ETH output using the constant product formula, sends ETH to the recipient,
     *      and transfers tokens from the buyer to the exchange.
     * @param _tokensSold Amount of tokens sold by the buyer.
     * @param _minEth Minimum amount of ETH the buyer is willing to receive.
     * @param _deadline Timestamp after which the transaction is no longer valid.
     * @param _buyer Address providing the tokens.
     * @param _recipient Address receiving the ETH.
     * @return ethBought Amount of ETH sent to the recipient.
     */
    function _tokenToEthInput(
        uint256 _tokensSold,
        uint256 _minEth,
        uint256 _deadline,
        address _buyer,
        address _recipient
    ) private returns (uint256) {
        if (_deadline < block.timestamp) {
            revert UniswapV1Exchange__DeadlineExpired();
        }
        if (_tokensSold == 0) {
            revert UniswapV1Exchange__TokensSoldIsZero();
        }
        if (_minEth == 0) {
            revert UniswapV1Exchange__MinEthIsZero();
        }

        uint256 tokenReserve = i_token.balanceOf(address(this));
        uint256 ethReserve = address(this).balance;

        uint256 ethBought = _getInputPrice(_tokensSold, tokenReserve, ethReserve);

        if (_minEth > ethBought) {
            revert UniswapV1Exchange__EthBoughtExceedsMinEth();
        }

        (bool successEthTransfer,) = _recipient.call{value: ethBought}("");
        if (!successEthTransfer) {
            revert UniswapV1Exchange__EthTransferFailed(_recipient, ethBought);
        }

        bool successTokenTransfer = i_token.transferFrom(_buyer, address(this), _tokensSold);
        if (!successTokenTransfer) {
            revert UniswapV1Exchange__TokenTransferFailed(_buyer, address(this), _tokensSold);
        }

        emit EthPurchase(_buyer, _tokensSold, ethBought);
        return ethBought;
    }

    /**
     * @notice Swaps tokens for an exact amount of ETH.
     * @dev Shared internal logic used by tokenToEthSwapOutput and tokenToEthTransferOutput.
     *      Calculates the required token input using the constant product formula,
     *      sends ETH to the recipient, and transfers tokens from the buyer to the exchange.
     * @param _ethBought Exact amount of ETH the recipient will receive.
     * @param _maxTokens Maximum amount of tokens the buyer is willing to sell.
     * @param _deadline Timestamp after which the transaction is no longer valid.
     * @param _buyer Address providing the tokens.
     * @param _recipient Address receiving the ETH.
     * @return tokensSold Amount of tokens sold by the buyer.
     */
    function _tokenToEthOutput(
        uint256 _ethBought,
        uint256 _maxTokens,
        uint256 _deadline,
        address _buyer,
        address _recipient
    ) private returns (uint256) {
        if (_deadline <= block.timestamp) {
            revert UniswapV1Exchange__DeadlineExpired();
        }

        if (_ethBought == 0) {
            revert UniswapV1Exchange__EthBoughtIsZero();
        }

        uint256 tokenReserve = i_token.balanceOf(address(this));
        uint256 ethReserve = address(this).balance;

        uint256 tokensSold = _getOutputPrice(_ethBought, tokenReserve, ethReserve);

        if (_maxTokens < tokensSold) {
            revert UniswapV1Exchange__TokensSoldExceedsMaxTokens();
        }

        (bool ethTransferSuccess,) = _recipient.call{value: _ethBought}("");
        if (!ethTransferSuccess) {
            revert UniswapV1Exchange__EthTransferFailed(_recipient, _ethBought);
        }

        bool tokenTransferSuccess = i_token.transferFrom(_buyer, address(this), tokensSold);

        if (!tokenTransferSuccess) {
            revert UniswapV1Exchange__TokenTransferFailed(_buyer, address(this), tokensSold);
        }

        emit EthPurchase(_buyer, tokensSold, _ethBought);

        return tokensSold;
    }

    /**
     * @notice Swaps an exact amount of this exchange token for another ERC20 token through ETH.
     * @dev Internal shared logic used by tokenToTokenSwapInput and tokenToTokenTransferInput.
     *      The swap is routed as Token A -> ETH -> Token B using the destination exchange.
     * @param _tokensSold Exact amount of this exchange token sold by the buyer.
     * @param _minTokensBought Minimum amount of output tokens the recipient is willing to receive.
     * @param _minEthBought Minimum amount of intermediate ETH that must be bought.
     * @param _deadline Timestamp after which the transaction is no longer valid.
     * @param _buyer Address providing the input tokens.
     * @param _recipient Address receiving the output tokens.
     * @param _exchangeAddr Address of the destination exchange for the output token.
     * @return tokensBought Amount of output tokens bought for the recipient.
     */
    function _tokenToTokenInput(
        uint256 _tokensSold,
        uint256 _minTokensBought,
        uint256 _minEthBought,
        uint256 _deadline,
        address _buyer,
        address _recipient,
        address payable _exchangeAddr
    ) private returns (uint256) {
        if (_deadline < block.timestamp) {
            revert UniswapV1Exchange__DeadlineExpired();
        }
        if (_tokensSold == 0) {
            revert UniswapV1Exchange__TokensSoldIsZero();
        }
        if (_minTokensBought == 0) {
            revert UniswapV1Exchange__MinTokensBoughtIsZero();
        }
        if (_minEthBought == 0) {
            revert UniswapV1Exchange__MinEthBoughtIsZero();
        }
        if (_exchangeAddr == address(this) || _exchangeAddr == address(0)) {
            revert UniswapV1Exchange__InvalidExchange();
        }

        uint256 tokenReserve = i_token.balanceOf(address(this));
        uint256 ethReserve = address(this).balance;

        uint256 ethBought = _getInputPrice(_tokensSold, tokenReserve, ethReserve);

        if (_minEthBought > ethBought) {
            revert UniswapV1Exchange__InsufficientEthBought();
        }

        bool tokenSoldTransferSuccess = i_token.transferFrom(_buyer, address(this), _tokensSold);
        if (!tokenSoldTransferSuccess) {
            revert UniswapV1Exchange__TokenTransferFailed(_buyer, address(this), _tokensSold);
        }

        uint256 tokensBought = UniswapV1Exchange(_exchangeAddr).ethToTokenTransferInput{value: ethBought}(
            _minTokensBought, _deadline, _recipient
        );

        emit EthPurchase(_buyer, _tokensSold, ethBought);
        return tokensBought;
    }

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

    /**
     * @notice Public price function for ETH to Token trades with an exact output.
     * @param _tokensBought Amount of Tokens bought.
     * @return Amount of ETH needed to buy output Tokens.
     */
    function getEthToTokenOutputPrice(uint256 _tokensBought) public view returns (uint256) {
        if (_tokensBought == 0) {
            revert UniswapV1Exchange__TokensBoughtIsZero();
        }
        uint256 tokenReserve = i_token.balanceOf(address(this));
        uint256 ethReserve = address(this).balance;
        return _getOutputPrice(_tokensBought, ethReserve, tokenReserve);
    }

    /**
     * @notice Public price function for Token to ETH trades with an exact input
     * @param _tokensSold Amount of Tokens sold.
     * @return Amount of ETH that can be bought with input Tokens.
     */
    function getTokenToEthInputPrice(uint256 _tokensSold) external view returns (uint256) {
        if (_tokensSold == 0) {
            revert UniswapV1Exchange__TokensSoldIsZero();
        }
        uint256 tokenReserve = i_token.balanceOf(address(this));
        uint256 ethReserve = address(this).balance;

        return _getInputPrice(_tokensSold, tokenReserve, ethReserve);
    }

    /**
     * @notice Returns the amount of tokens required to buy an exact amount of ETH.
     * @param _ethBought Exact amount of ETH the user wants to receive.
     * @return tokensSold Amount of tokens required to buy `_ethBought`.
     */
    function getTokenToEthOutputPrice(uint256 _ethBought) external view returns (uint256) {
        if (_ethBought == 0) {
            revert UniswapV1Exchange__EthBoughtIsZero();
        }
        uint256 tokenReserve = i_token.balanceOf(address(this));
        uint256 ethReserve = address(this).balance;
        return _getOutputPrice(_ethBought, tokenReserve, ethReserve);
    }
}
