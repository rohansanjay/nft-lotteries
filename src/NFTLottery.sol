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

    event NewLotteryListed(uint256 indexed lotteryId, Lottery lottery);
    event LotteryCancelled(uint256 indexed lotteryId, Lottery Lottery);
    event LotteryWon(uint256 indexed lotteryId, address user, Lottery lottery);
    event LotteryLost(uint256 indexed lotteryId, address user, Lottery lottery);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized();
    error BetAmountZero();
    error InvalidWinProbability();
    error InsufficientFunds();

    /*//////////////////////////////////////////////////////////////
                             EXTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit NFT into contract and list lottery
    /// @param _nftCollection The contract address of the NFT collection
    /// @param _tokenId The id of the NFT within the collection
    /// @param _betAmount The required wager to win the NFT 
    /// @param _winProbability The probability of winning the NFT (6-decimal places)
    function listLottery(
        address _nftCollection,
        uint256 _tokenId,
        uint256 _betAmount,
        uint256 _winProbability
    ) external payable {
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

        emit NewLotteryListed(nextLotteryId++, lottery);

        lottery.nftCollection.safeTransferFrom(msg.sender, address(this), lottery.tokenId);
    }

    /// @notice Cancel lottery and send NFT back to original owner
    /// @param _lotteryId The ID of the lottery to cancel
    function cancelLottery(uint256 _lotteryId) external payable {
        Lottery memory lottery = openLotteries[_lotteryId];

        // Only the original owner can withdraw
        if (lottery.nftOwner != msg.sender) revert Unauthorized(); 

        delete openLotteries[_lotteryId];

        emit LotteryCancelled(_lotteryId, lottery);

        lottery.nftCollection.safeTransferFrom(address(this), msg.sender, lottery.tokenId);
    }

    function placeBet(uint256 _lotteryId) external payable {
        Lottery memory lottery = openLotteries[_lotteryId];

        // Ensure funds sent cover betAmount specified by NFT owner
        if (msg.value < lottery.betAmount) revert InsufficientFunds(); 

        // Refund any extra ETH to sender
        if (msg.value > lottery.betAmount) {
            payable(msg.sender).transfer(msg.value - lottery.betAmount);
        }

        // Send bet amount to nft owner
        payable(lottery.nftOwner).transfer(lottery.betAmount);

        _settleBet(msg.sender, _lotteryId, lottery); 
    }

    /*//////////////////////////////////////////////////////////////
                             INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/ 

    function _settleBet(address _user, uint _lotteryId, Lottery memory _lottery) internal {
        uint256 _rng = _generateRandomNumber();

        // If random number is ≤ win probability, sender wins the lottery
        if (_rng <= _lottery.winProbability) {
            delete openLotteries[_lotteryId];
            
            emit LotteryWon(_lotteryId, _user, _lottery);

            _lottery.nftCollection.safeTransferFrom(address(this), _user, _lottery.tokenId); 
        } else {
            emit LotteryLost(_lotteryId, _user, _lottery);
        }
    }

    function _generateRandomNumber() internal pure returns (uint256) {
        // TODO: chainlink vrf
        return 1;
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