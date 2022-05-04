// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.12;

import { ERC721 } from "solmate/tokens/ERC721.sol";
import { IERC721TokenReceiver } from "./interfaces/IERC721TokenReceiver.sol";
import { VRFConsumerBaseV2 } from "chainlink/v0.8/VRFConsumerBaseV2.sol";
import { VRFCoordinatorV2Interface } from "chainlink/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import { Ownable } from "oz/access/Ownable.sol";

contract NFTLottery is VRFConsumerBaseV2, Ownable {

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/ 

    event NewLotteryListed(uint256 indexed lotteryId, Lottery lottery);
    event LotteryCancelled(uint256 indexed lotteryId, Lottery lottery);
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
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fees are 6-decimal places. Ex: 10 * 10**6 = 10%
    uint256 internal constant PROBABILITY_MULTIPLIER = 10**6;

    /*//////////////////////////////////////////////////////////////
                            NFT LOTTERY STATE
    //////////////////////////////////////////////////////////////*/

    /// @dev Parameters for Lotteries
    /// @param nftOwner The address of the original NFT owner
    /// @param nftCollection The collection of the NFT offered
    /// @param tokenId The Id of the NFT within the collection
    /// @param betAmount The required wager to win the NFT 
    /// @param winProbability The probability of winning the NFT (6-decimal places)
    struct Lottery {
        address nftOwner;
        ERC721 nftCollection;
        uint256 tokenId;
        uint256 betAmount;
        uint256 winProbability;
    }

    /// @notice A list of all NFT Lotteries indexed by lottery Id
    mapping (uint256 => Lottery) public openLotteries;

    /// @notice The Id used for the next Lottery
    uint256 public nextLotteryId = 1;

    /*//////////////////////////////////////////////////////////////
                                VRF STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice VRF coordinator contract
    VRFCoordinatorV2Interface internal COORDINATOR;

    /// @notice VRF subscription Id used for funding requests
    uint64 internal s_subscriptionId;

    /// @notice VRF address of coordinator see https://docs.chain.link/docs/vrf-contracts/#configurations
    address internal vrfCoordinator;

    /// @notice VRF gas lane see https://docs.chain.link/docs/vrf-contracts/#configurations
    bytes32 internal keyHash;

    /// @notice VRF number of confirmations node waits before responding
    uint16 internal requestConfirmations = 20;

    /// @notice VRF callback request gas limit
    uint32 internal callbackGasLimit = 100000;

    /// @notice VRF number of random values in one request
    uint32 internal numWords =  1;

    /// @notice VRF maps request Id of random number to lottery Id of NFT being bet on
    mapping(uint256 => uint256) public vrfRequestIdToLotteryId;

    /// @notice VRF maps request Id of random number to requester address placing bet
    mapping(uint256 => address) public vrfRequestIdToAddress;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates new NFT lottery contract and Chainlink VRF
    /// @param _subscriptionId The subscription Id the contract will use for funding requests
    /// @param _vrfCoordinator The address of the Chainlink VRF contract
    /// @param _keyHash The gas lane key hash value for VRF job
    constructor(uint64 _subscriptionId, address _vrfCoordinator, bytes32 _keyHash) VRFConsumerBaseV2(_vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        keyHash = _keyHash;
        s_subscriptionId = _subscriptionId;
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
    /// @param _lotteryId The Id of the lottery to cancel
    function cancelLottery(uint256 _lotteryId) external payable {
        Lottery memory lottery = openLotteries[_lotteryId];

        // Only the original owner can withdraw
        if (lottery.nftOwner != msg.sender) revert Unauthorized(); 

        delete openLotteries[_lotteryId];

        emit LotteryCancelled(_lotteryId, lottery);

        lottery.nftCollection.safeTransferFrom(address(this), msg.sender, lottery.tokenId);
    }

    /// @notice User bets on NFT and function calls VRF for random number
    /// @param _lotteryId The Id of the lottery with NFT being bet on
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

        // Random number generation
        uint256 requestId = requestRandomWords();

        // Map requestId to lottery and user address to reference when random number is received from VRF
        // TODO: reentrancy?
        vrfRequestIdToLotteryId[requestId] = _lotteryId;
        vrfRequestIdToAddress[requestId] = msg.sender;
    }

    /*//////////////////////////////////////////////////////////////
                             INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/ 

    /// @notice Settles pending bet in a lottery by simulating random outcome
    /// @param _requestId The Id of the VRF request
    /// @param _randomNumber The random number generated by VRF
    function _settleBet(uint256 _requestId, uint256 _randomNumber) internal {
        uint256 lotteryId = vrfRequestIdToLotteryId[_requestId];
        address user = vrfRequestIdToAddress[_requestId];
        Lottery memory lottery = openLotteries[lotteryId];

        // If random number is ≤ win probability, user wins the lottery (corresponds to lottery.winProbability chance of winning)
        if (_randomNumber <= lottery.winProbability) {
            delete openLotteries[lotteryId];
            
            emit LotteryWon(lotteryId, user, lottery);

            lottery.nftCollection.safeTransferFrom(address(this), user, lottery.tokenId); 
        } else {
            emit LotteryLost(lotteryId, user, lottery);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                VRF LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Requests random number from Chainlink VRF 
    /// @return The Id of the VRF request
    function requestRandomWords() internal onlyOwner returns (uint256) {
        uint256 requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
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
        uint256 _randomNumber = randomWords[0] % (100 * PROBABILITY_MULTIPLIER + 1);

        // settle bet once VRF random number is returned
        _settleBet(requestId, _randomNumber);
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