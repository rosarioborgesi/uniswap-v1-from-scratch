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

import {UniswapV1Exchange} from "./UniswapV1Exchange.sol";

contract UniswapV1Factory {
    ////////////////////////////////
    //            Errors          //
    ////////////////////////////////
    error UniswapV1Factory__ZeroAddress();
    error UniswapV1Factory__ExchangeAlreadyExists();

    ////////////////////////////////
    //      State Variables       //
    ////////////////////////////////
    mapping(address token => address exchange) private s_tokenToExchange;
    mapping(address exchange => address token) private s_exchangeToToken;
    mapping(uint256 id => address token) private s_idToToken;

    uint256 private s_tokenCount;

    ////////////////////////////////
    //           Events           //
    ////////////////////////////////
    event NewExchange(address indexed token, address indexed exchange);

    ////////////////////////////////
    //          Functions         //
    ////////////////////////////////

    ////////////////////////////////
    //     External Functions     //
    ////////////////////////////////
    /**
     * @notice Creates a new exchange for a given ERC20 token.
     * @param _token Address of the ERC20 token supported by the new exchange.
     * @param _lpTokenName Name of the LP token minted by the exchange.
     * @param _lpTokenSymbol Symbol of the LP token minted by the exchange.
     * @return exchangeAddress Address of the newly created exchange.
     */
    function createExchange(address _token, string memory _lpTokenName, string memory _lpTokenSymbol)
        external
        returns (address)
    {
        if (_token == address(0)) {
            revert UniswapV1Factory__ZeroAddress();
        }
        if (s_tokenToExchange[_token] != address(0)) {
            revert UniswapV1Factory__ExchangeAlreadyExists();
        }

        UniswapV1Exchange exchange = new UniswapV1Exchange(_token, _lpTokenName, _lpTokenSymbol);
        address exchangeAddress = address(exchange);

        s_tokenToExchange[_token] = exchangeAddress;
        s_exchangeToToken[exchangeAddress] = _token;

        s_tokenCount++;
        s_idToToken[s_tokenCount] = _token;

        emit NewExchange(_token, exchangeAddress);

        return exchangeAddress;
    }

    //////////////////////////////////////////////////////
    //      External & Public View & Pure Functions     //
    //////////////////////////////////////////////////////
    /**
     * @notice Returns the exchange address associated with a token.
     * @param _token Address of the ERC20 token.
     * @return exchange Address of the exchange supporting the token.
     */
    function getExchange(address _token) external view returns (address exchange) {
        return s_tokenToExchange[_token];
    }

    /**
     * @notice Returns the token associated with an exchange.
     * @param _exchange Address of the exchange.
     * @return token Address of the ERC20 token supported by the exchange.
     */
    function getToken(address _exchange) external view returns (address token) {
        return s_exchangeToToken[_exchange];
    }

    /**
     * @notice Returns the token associated with a given token id.
     * @param _tokenId Unique token identifier assigned by the factory.
     * @return token Address of the ERC20 token.
     */
    function getTokenWithId(uint256 _tokenId) external view returns (address token) {
        return s_idToToken[_tokenId];
    }

    /**
     * @notice Returns the number of exchanges created by the factory.
     * @return count Total number of registered tokens/exchanges.
     */
    function tokenCount() external view returns (uint256 count) {
        return s_tokenCount;
    }
}
