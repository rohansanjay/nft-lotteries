// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.12;

import { ERC721 } from "solmate/tokens/ERC721.sol";

contract Lottery {

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The address of the NFT
    address public immutable nftAddress;

    /// @notice The address of the NFT owner
    address public immutable nftOnwer;

    /// @notice The collection of the NFT to lend
    ERC721 public immutable nftCollection;

    /// @notice The the id of the NFT within the collection
    uint256 public immutable nftId;

    /*//////////////////////////////////////////////////////////////
                                  STATE
    //////////////////////////////////////////////////////////////*/
    
    /// @notice The amount required to bet on winning the NFT
    uint256 public betAmount; 
    
    /// @notice The amount required to bet on winning the NFT (scaled by 10^-6)
    uint256 public betWinningOdds; 

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/ 

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotNFTOnwer();
    error BetAmountZero();
    error BetOddsZero();

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice NFT Lottery creation
    constructor(
        address _nftAddress,
        address _nftOwner,
        address _nftCollection,
        uint256 _nftId,
        uint256 _betAmount,
        uint256 _betWinningOdds
    ) {

        // Require that the contract creator owns the specified NFT
        if (ERC721(_nftAddress).ownerOf(_nftId) != msg.sender) revert NotNFTOnwer();

        // Require bet amount to win NFT must be greater than 0
        if (_betAmount == 0) revert BetAmountZero();

        // Require bet odds to win NFT must be greater than 0
        if (_betWinningOdds == 0) revert BetOddsZero();


        nftAddress = _nftAddress;
        nftOnwer = _nftOwner;
        nftCollection = ERC721(_nftCollection);
        nftId = _nftId;
        betAmount = _betAmount; 
        betWinningOdds = _betWinningOdds; 
    }
}