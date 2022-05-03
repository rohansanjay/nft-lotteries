// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.12;

import { ERC721 } from "solmate/tokens/ERC721.sol";
import { IERC721TokenReceiver } from "./interfaces/IERC721TokenReceiver.sol";

contract NFTLottery {

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fees are 6-decimal places. Ex: 10 * 10**6 = 10%
    uint256 internal constant PROBABILITY_MULTIPLIER = 10**6;

    /*//////////////////////////////////////////////////////////////
                                  STATE
    //////////////////////////////////////////////////////////////*/

    /// @dev Parameters for Lotteries
    /// @param nftOwner The address of the original NFT owner
    /// @param nftCollection The collection of the NFT offered
    /// @param tokenId The id of the NFT within the collection
    /// @param betAmount The required wager to win the NFT 
    /// @param winProbability The probability of winning the NFT (6-decimal places)
    struct Lottery {
        address nftOwner;
        ERC721 nftCollection;
        uint256 tokenId;
        uint256 betAmount;
        uint256 winProbability;
    }

    /// @notice An indexed list of all NFT Lotteries
    mapping (uint256 => Lottery) public openLotteries;

    /// @notice The Id used for the next Lottery
    uint256 public nextLotteryId = 1;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/ 

    event NewLotteryListed(Lottery lottery);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized();
    error BetAmountZero();
    error InvalidWinProbability();

    /*//////////////////////////////////////////////////////////////
                             EXTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice List an NFT Lottery
    /// @param _nftCollection The contract address of the NFT collection
    /// @param _tokenId The id of the NFT within the collection
    /// @param _betAmount The required wager to win the NFT 
    /// @param _winProbability The probability of winning the NFT (6-decimal places)
    /// @return The ID of the created listing
    function listNFTLottery(
        address _nftCollection,
        uint256 _tokenId,
        uint256 _betAmount,
        uint256 _winProbability
    ) external payable returns (uint256) {

        // The lister must own the NFT
        if (ERC721(_nftCollection).ownerOf(_tokenId) != msg.sender) revert Unauthorized();

        // The specified bet amount to win the NFT must be greater than 0
        if (_betAmount == 0) revert BetAmountZero();

        // The probability of winning must be > 0 and ≤ 100
        if (_winProbability == 0 || _winProbability > 100 * PROBABILITY_MULTIPLIER) revert InvalidWinProbability();

        Lottery memory lottery = Lottery({
            nftOwner: msg.sender,
            nftCollection: ERC721(_nftCollection),
            tokenId: _tokenId,
            betAmount: _betAmount,
            winProbability: _winProbability
        });

        openLotteries[nextLotteryId] = lottery;

        emit NewLotteryListed(lottery);

        lottery.nftCollection.safeTransferFrom(msg.sender, address(this), lottery.tokenId);

        return nextLotteryId++;
    }

    /*//////////////////////////////////////////////////////////////
                         ERC-721 RECEIVER LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Allows this contract to custody ERC721 Tokens
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721TokenReceiver.onERC721Received.selector;
    }
}