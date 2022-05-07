// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.12;

import { NFTLotteries } from "../NFTLotteries.sol";
import { MockERC721 } from "solmate/test/utils/mocks/MockERC721.sol";
import { VRFCoordinatorV2Mock } from "chainlink/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import { ERC721 } from "solmate/tokens/ERC721.sol";
import "forge-std/Test.sol";

contract NFTLotteryTest is Test {
    NFTLotteries nftLotteries;

    /// @dev Multiplier for Percentages
    uint256 public constant PERCENT_MULTIPLIER = 10**6;

    /// @dev Mock Actors
    address public nftOwner = address(69);
    address public nftBetter = address(420);   

    /// @dev Mock NFT
    MockERC721 public mockNFT;

    /// @dev Owned ERC721 Token Id
    uint256 public tokenId = 8888;   

    /// @dev Mock VRF Coordinator
    VRFCoordinatorV2Mock public mockCoordinator;

    /// @dev VRF Params
    uint64 public subscriptionId = 1;
    bytes32 public keyHash = 0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef;

    /// @dev Lottery Params
    uint256 public rake = 0;
    address public rakeRecipient = address(42069);
    uint256 betAmount = 1 ether;
    uint256 winProbability = 1 * PERCENT_MULTIPLIER;

    /// @dev Events
    event NewLotteryListed(uint256 indexed lotteryId, NFTLotteries.Lottery lottery);
    event LotteryCancelled(uint256 indexed lotteryId, NFTLotteries.Lottery lottery);
    event NewBet(NFTLotteries.Bet bet);
    event BetSettled(bool indexed won, NFTLotteries.Bet bet, NFTLotteries.Lottery lottery);
    event RakeSet(uint256 oldRake, uint256 newRake);

    function setUp() public {
        // Create mock NFT 
        mockNFT = new MockERC721("Mock NFT", "MOCK");

        // Mint to owner
        mockNFT.mint(nftOwner, tokenId);

        // Give better balance
        vm.deal(nftBetter, type(uint256).max);

        // Create Mock Coordinator
        mockCoordinator = new VRFCoordinatorV2Mock(0, 0);

        // Create NFTLottery
        nftLotteries = new NFTLotteries(
            subscriptionId,
            address(mockCoordinator),
            keyHash,
            rake,
            rakeRecipient
        );
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function testInvalidVrfCoordinatorCannotConstruct() public {
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("InvalidAddress()"))));
        nftLotteries = new NFTLotteries(
            subscriptionId,
            address(0),
            keyHash,
            rake,
            rakeRecipient
        );
    }

    function testRakeOverHundredCannotConstruct() public {
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("InvalidPercent()"))));
        nftLotteries = new NFTLotteries(
            subscriptionId,
            address(mockCoordinator),
            keyHash,
            100000001,
            rakeRecipient
        );
    }

    function testInvalidRakeRecipientCannotConstruct() public {
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("InvalidAddress()"))));
        nftLotteries = new NFTLotteries(
            subscriptionId,
            address(mockCoordinator),
            keyHash,
            rake,
            address(0)
        );
    }
    
    /*//////////////////////////////////////////////////////////////
                              LIST LOTTERY
    //////////////////////////////////////////////////////////////*/

    function testNonOwnerCannotListLottery() public {
        assertEq(mockNFT.ownerOf(tokenId), nftOwner);

        hoax(address(1));
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("Unauthorized()"))));
        nftLotteries.listLottery(address(mockNFT), tokenId, 1 ether, 1 * PERCENT_MULTIPLIER);

        assertEq(mockNFT.ownerOf(tokenId), nftOwner);
    }

    function testZeroBetAmountCannotListLottery() public {
        assertEq(mockNFT.ownerOf(tokenId), nftOwner);

        hoax(nftOwner);

        vm.expectRevert(abi.encodePacked(bytes4(keccak256("BetAmountZero()"))));
        nftLotteries.listLottery(address(mockNFT), tokenId, 0, 1 * PERCENT_MULTIPLIER);

        assertEq(mockNFT.ownerOf(tokenId), nftOwner);
    }

    function testZeroWinProbabilityCannotListLottery() public {
        assertEq(mockNFT.ownerOf(tokenId), nftOwner);

        startHoax(nftOwner);

        vm.expectRevert(abi.encodePacked(bytes4(keccak256("InvalidPercent()"))));
        nftLotteries.listLottery(address(mockNFT), tokenId, 1 ether, 0 * PERCENT_MULTIPLIER);

        assertEq(mockNFT.ownerOf(tokenId), nftOwner);
    }

    function testAboveHundredWinProbabilityCannotListLottery() public {
        assertEq(mockNFT.ownerOf(tokenId), nftOwner);

        hoax(nftOwner);

        vm.expectRevert(abi.encodePacked(bytes4(keccak256("InvalidPercent()"))));
        nftLotteries.listLottery(address(mockNFT), tokenId, 1 ether, 101 * PERCENT_MULTIPLIER);

        assertEq(mockNFT.ownerOf(tokenId), nftOwner);
    }

    function testNftTransferNotApprovedCannotListLottery() public {
        assertEq(mockNFT.ownerOf(tokenId), nftOwner);

        hoax(nftOwner);

        vm.expectRevert("NOT_AUTHORIZED");
        nftLotteries.listLottery(address(mockNFT), tokenId, betAmount, winProbability);

        assertEq(mockNFT.ownerOf(tokenId), nftOwner);
    }

    function testCanListLottery() public {
        assertEq(mockNFT.ownerOf(tokenId), nftOwner);

        startHoax(nftOwner);

        mockNFT.approve(address(nftLotteries), tokenId);

        uint256 lotteryId = nftLotteries.nextLotteryId();
        vm.expectEmit(true, false, false, true);
        emit NewLotteryListed(
            lotteryId, 
            NFTLotteries.Lottery({
                nftOwner: nftOwner,
                nftCollection: mockNFT,
                tokenId: tokenId,
                betAmount: betAmount,
                winProbability: winProbability,
                betIsPending: false
            }) 
        );

        nftLotteries.listLottery(address(mockNFT), tokenId, betAmount, winProbability);

        assertEq(mockNFT.ownerOf(tokenId), address(nftLotteries));
        assertEq(nftLotteries.nextLotteryId(), lotteryId + 1);

        (
            address _nftOwner, 
            ERC721 _nftCollection, 
            uint256 _tokenId, 
            uint256 _betAmount, 
            uint256 _winProbability, 
            bool _betIsPending
        ) = nftLotteries.openLotteries(lotteryId);

        assertEq(nftOwner, _nftOwner);
        assertEq(address(mockNFT), address(_nftCollection));
        assertEq(tokenId, _tokenId);
        assertEq(betAmount, _betAmount);
        assertEq(winProbability, _winProbability);
        assertEq(false, _betIsPending);
    }
}
