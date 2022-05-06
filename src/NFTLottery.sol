// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.12;

import { ERC721 } from "solmate/tokens/ERC721.sol";
import { IERC721TokenReceiver } from "./interfaces/IERC721TokenReceiver.sol";
import { VRFConsumerBaseV2 } from "chainlink/v0.8/VRFConsumerBaseV2.sol";
import { VRFCoordinatorV2Interface } from "chainlink/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import { Ownable } from "oz/access/Ownable.sol";

/// @title NFT Lotteries
/// @author Rohan Sanjay (https://github.com/rohansanjay/nft-lotteries)
/// @notice An NFT Betting Platform
contract NFTLottery is VRFConsumerBaseV2, Ownable {

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/ 

    event NewLotteryListed(uint256 indexed lotteryId, Lottery lottery);
    event LotteryCancelled(uint256 indexed lotteryId, Lottery lottery);
    event NewBet(Bet bet);
    event BetSettled(bool indexed won, Bet bet, Lottery lottery);
    event RakeSet(uint256 oldRake, uint256 newRake);
    
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized();
    error BetAmountZero();
    error InvalidPercent();
    error InsufficientFunds();
    error BetIsPending();
    error WrongLotteryId();
    error InvalidAddress();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Percents are 6-decimal places. Ex: 10 * 10**6 = 10%
    uint256 internal constant PERCENT_MULTIPLIER = 10**6;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Parameters for Lotteries
    /// @param nftOwner The address of the original NFT owner
    /// @param nftCollection The collection of the NFT offered
    /// @param tokenId The Id of the NFT within the collection
    /// @param betAmount The required wager to win the NFT 
    /// @param winProbability The probability of winning the NFT (6-decimal places)
    /// @param betIsPending Store if a bet on the Lottery is pending
    struct Lottery {
        address nftOwner;
        ERC721 nftCollection;
        uint256 tokenId;
        uint256 betAmount;
        uint256 winProbability;
        bool betIsPending;
    }

    /// @dev Parameters for Bet
    /// @param lotteryId Lottery Id of Bet
    /// @param requestor Address of user making Bet
    struct Bet {
        uint256 lotteryId;
        address user;
    }

    /*//////////////////////////////////////////////////////////////
                            NFT LOTTERY STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice A list of all NFT Lotteries indexed by lottery Id
    mapping (uint256 => Lottery) public openLotteries;

    /// @notice The Id used for the next Lottery
    uint256 public nextLotteryId = 1;

    /// @notice Rake fee (6 decimals). ex: 10 * 10 ** 6 = 10%
    uint256 public rake;

    /// @notice Recipient of rake fee
    address public rakeRecipient;

    /*//////////////////////////////////////////////////////////////
                                VRF STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice VRF coordinator contract
    VRFCoordinatorV2Interface internal COORDINATOR;

    /// @notice VRF address of coordinator see https://docs.chain.link/docs/vrf-contracts/#configurations
    address internal vrfCoordinator;

    /// @notice VRF gas lane see https://docs.chain.link/docs/vrf-contracts/#configurations
    bytes32 public keyHash;

    /// @notice VRF subscription Id used for funding requests
    uint64 public subscriptionId;

    /// @notice VRF callback request gas limit
    uint32 public callbackGasLimit = 100000;

    /// @notice VRF number of random values in one request
    uint32 internal numWords =  1;

    /// @notice VRF number of confirmations node waits before responding
    uint16 public requestConfirmations = 20;

    /// @notice VRF maps request Id corresponding Bet
    mapping(uint256 => Bet) public vrfRequestIdToBet;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates new NFT lottery contract and Chainlink VRF
    /// @param _subscriptionId The subscription Id the contract will use for funding requests
    /// @param _vrfCoordinator The address of the Chainlink VRF contract
    /// @param _keyHash The gas lane key hash value for VRF job
    /// @param _rake The rake fee
    /// @param _rakeRecipient The address that will receive the rake fee
    constructor(
        uint64 _subscriptionId, 
        address _vrfCoordinator, 
        bytes32 _keyHash,
        uint256 _rake,
        address _rakeRecipient
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        if (_vrfCoordinator == address(0)) revert InvalidAddress();
        if (_rake > 100 * PERCENT_MULTIPLIER) revert InvalidPercent();
        if (_rakeRecipient == address(0)) revert InvalidAddress();

        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        keyHash = _keyHash;
        subscriptionId = _subscriptionId;
        rake = _rake;
        rakeRecipient = _rakeRecipient;
    }

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

        // The probability of winning must be > 0 and < 100 (because we include 0)
        if (_winProbability == 0 || _winProbability > 100 * PERCENT_MULTIPLIER) revert InvalidPercent();

        Lottery memory lottery = Lottery({
            nftOwner: msg.sender,
            nftCollection: ERC721(_nftCollection),
            tokenId: _tokenId,
            betAmount: _betAmount,
            winProbability: _winProbability,
            betIsPending: false
        });

        openLotteries[nextLotteryId] = lottery;

        emit NewLotteryListed(nextLotteryId++, lottery);

        lottery.nftCollection.safeTransferFrom(msg.sender, address(this), lottery.tokenId);
    }

    /// @notice Cancel lottery and send NFT back to original owner
    /// @param _lotteryId The Id of the lottery to cancel
    function cancelLottery(uint256 _lotteryId) external payable {
        Lottery memory lottery = openLotteries[_lotteryId];

        // Only the original owner can withdraw
        if (lottery.nftOwner != msg.sender) revert Unauthorized(); 

        // Cannot cancel a Lottery if there is a pending bet
        if (lottery.betIsPending) revert BetIsPending();

        delete openLotteries[_lotteryId];

        emit LotteryCancelled(_lotteryId, lottery);

        lottery.nftCollection.safeTransferFrom(address(this), msg.sender, lottery.tokenId);
    }

    /// @notice User bets on NFT and function calls VRF for random number
    /// @param _lotteryId The Id of the lottery with NFT being bet on
    function placeBet(uint256 _lotteryId) external payable {
        Lottery memory lottery = openLotteries[_lotteryId];

        // Check if the Lottery Id is valid (win probability can't be 0)
        if (lottery.winProbability == 0) revert WrongLotteryId();

        // Cannot place a bet if there is already one pending (reentrancy check)
        if (lottery.betIsPending) revert BetIsPending();

        // Ensure funds sent cover betAmount specified by NFT owner
        if (msg.value < lottery.betAmount) revert InsufficientFunds(); 

        // Refund any extra ETH to sender
        if (msg.value > lottery.betAmount) {
            payable(msg.sender).transfer(msg.value - lottery.betAmount);
        }

        // Change betIsPending to true
        _flipBetIsPendingStatus(_lotteryId, lottery.betIsPending);

        // Send rake to rake recipient
        uint256 rakeAmount = (lottery.betAmount * rake) / (100 * PERCENT_MULTIPLIER);
        payable(rakeRecipient).transfer(rakeAmount);

        // Send bet amount to nft owner after deducting rake
        payable(lottery.nftOwner).transfer(lottery.betAmount - rakeAmount);

        // Random number generation
        uint256 requestId = requestRandomWords();

        Bet memory bet = Bet({
            lotteryId: _lotteryId,        
            user: msg.sender
        });

        vrfRequestIdToBet[requestId] = bet;

        emit NewBet(bet);
    }

    /*//////////////////////////////////////////////////////////////
                             INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/ 

    /// @notice Settles pending bet in a lottery by simulating random outcome
    /// @param _requestId The Id of the VRF request
    /// @param _randomNumber The random number generated by VRF
    function _settleBet(uint256 _requestId, uint256 _randomNumber) internal {
        Bet memory bet = vrfRequestIdToBet[_requestId];
        Lottery memory lottery = openLotteries[bet.lotteryId];

        // If random number is ≤ win probability, user wins the lottery (corresponds to lottery.winProbability chance of winning)
        if (_randomNumber <= lottery.winProbability) {
            delete openLotteries[bet.lotteryId];
            
            emit BetSettled(true, bet, lottery);

            lottery.nftCollection.safeTransferFrom(address(this), bet.user, lottery.tokenId); 
        } else {
            emit BetSettled(false, bet, lottery);

            // Change bet status from pending
            _flipBetIsPendingStatus(bet.lotteryId, lottery.betIsPending);
        }

        delete vrfRequestIdToBet[_requestId];
    }

    /// @notice Flips pending bet status
    /// @param _lotteryId The Id of the Lottery to change pending status for
    /// @param _status The current betIsPending value for the Lottery
    function _flipBetIsPendingStatus(uint256 _lotteryId, bool _status) internal {
        _status ? openLotteries[_lotteryId].betIsPending = false : openLotteries[_lotteryId].betIsPending = true;
    }

    /*//////////////////////////////////////////////////////////////
                                VRF LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Requests random number from Chainlink VRF 
    /// @return The Id of the VRF request
    function requestRandomWords() internal onlyOwner returns (uint256) {
        uint256 requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );

        // Return the requestId to the requester.
        return requestId;
    }

    /// @notice Receives random number from Chainlink VRF 
    /// @param requestId The Id initially returned by VRF request
    /// @param randomWords The VRF output 
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        // convert number into range 0 to 100 * 10^6
        // TODO: confirm this!
        uint256 _randomNumber = randomWords[0] % (100 * PERCENT_MULTIPLIER + 1);

        // settle bet once VRF random number is returned
        _settleBet(requestId, _randomNumber);
    }

    /*//////////////////////////////////////////////////////////////
                                 SETTERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets VRF key hash
    /// @param _keyHash the new key hash
    function setKeyHash(bytes32 _keyHash) external onlyOwner {
        keyHash = _keyHash;
    }

    /// @notice Sets VRF subscription Id
    /// @param _subscriptionId the new subscription Id
    function setSubscriptionId(uint64 _subscriptionId) external onlyOwner {
        subscriptionId = _subscriptionId;
    }

    /// @notice Sets VRF callback gas limit
    /// @param _callbackGasLimit the new callback gas limit
    function setCallbackGasLimit(uint32 _callbackGasLimit) external onlyOwner {
        callbackGasLimit = _callbackGasLimit;
    }

    /// @notice Sets VRF number of confirmations
    /// @param _requestConfirmations the new number of request confirmations
    function setRequestConfirmations(uint16 _requestConfirmations) external onlyOwner {
        requestConfirmations = _requestConfirmations;
    }

    /// @notice Sets the rake fee
    /// @param _rake New rake fee (6 decimals ex: 10 * 10 ** 6 = 10%)
    function setRake(uint256 _rake) external onlyOwner {
        if (rake > 100 * PERCENT_MULTIPLIER) revert InvalidPercent();

        emit RakeSet(rake, _rake);

        rake = _rake;
    }

    /// @notice Sets the rake fee recipient
    /// @param _rakeRecipient Address of new rake fee recipient
    function setRakeRecipient(address _rakeRecipient) external onlyOwner {
        if (_rakeRecipient == address(0) || _rakeRecipient == rakeRecipient) revert InvalidAddress();

        rakeRecipient = _rakeRecipient;
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