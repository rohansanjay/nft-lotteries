// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.12;

import { NFTLotteries } from "../NFTLotteries.sol";
import { MockERC721 } from "solmate/test/utils/mocks/MockERC721.sol";
import { ERC721 } from "solmate/tokens/ERC721.sol";
import { VRFCoordinatorV2Mock } from "chainlink/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import "forge-std/Test.sol";

contract NFTLotteryTest is Test {
    NFTLotteries public nftLotteries;

    /// @dev Owner
    address public constant OWNER = 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84;

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
    uint64 public subscriptionId;
    bytes32 public keyHash = 0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef;

    /// @dev Lottery Params
    uint256 public rake = 0;
    address public rakeRecipient = address(42069);
    uint256 public betAmount = 1 ether;
    uint256 public winProbability = 1 * PERCENT_MULTIPLIER;

    /// @dev Events
    event NewLotteryListed(NFTLotteries.Lottery lottery);
    event LotteryCancelled(uint256 indexed lotteryId, NFTLotteries.Lottery lottery);
    event NewBet(NFTLotteries.Bet bet);
    event BetSettled(bool indexed won, NFTLotteries.Bet bet, NFTLotteries.Lottery lottery);
    event RakeSet(uint256 oldRake, uint256 newRake);

    function setUp() public {
        // Create mock NFT 
        mockNFT = new MockERC721("Mock NFT", "MOCK");

        // Mint to owner
        mockNFT.mint(nftOwner, tokenId);

        // Create Mock Coordinator
        mockCoordinator = new VRFCoordinatorV2Mock(0, 0);
        subscriptionId = mockCoordinator.createSubscription();

        // Create NFTLottery
        nftLotteries = new NFTLotteries(
            subscriptionId,
            address(mockCoordinator),
            keyHash,
            rake,
            rakeRecipient
        );
        
        // Add contract as mock consumer
        mockCoordinator.addConsumer(subscriptionId, address(nftLotteries));
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

        vm.expectEmit(false, false, false, true);
        emit NewLotteryListed(
            NFTLotteries.Lottery({
                nftOwner: nftOwner,
                nftCollection: mockNFT,
                tokenId: tokenId,
                betAmount: betAmount,
                winProbability: winProbability,
                betIsPending: false
            }) 
        );

        uint256 lotteryId = nftLotteries.listLottery(address(mockNFT), tokenId, betAmount, winProbability);

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

    /*//////////////////////////////////////////////////////////////
                             CANCEL LOTTERY
    //////////////////////////////////////////////////////////////*/

    function testFuzzInvalidIdCannotCancelLottery(uint256 _fuzzLotteryId) public {
        // No lotteries currently exist
        assertEq(nftLotteries.nextLotteryId(), 1);

        // lottery.nftOwner will be address(0)
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("Unauthorized()"))));
        nftLotteries.cancelLottery(_fuzzLotteryId);
    }

    function testNonOwnerCannotCancelLottery() public {
        startHoax(nftOwner);
        mockNFT.approve(address(nftLotteries), tokenId);

        uint256 lotteryId = nftLotteries.listLottery(address(mockNFT), tokenId, betAmount, winProbability);
        (address _nftOwner, , , , ,) = nftLotteries.openLotteries(lotteryId);

        assertEq(nftOwner, _nftOwner);
        assertEq(mockNFT.ownerOf(tokenId), address(nftLotteries));
        vm.stopPrank();

        vm.expectRevert(abi.encodePacked(bytes4(keccak256("Unauthorized()"))));
        nftLotteries.cancelLottery(lotteryId);
    }

    function testBetIsPendingCannotCancelLottery() public {
        startHoax(nftOwner);
        mockNFT.approve(address(nftLotteries), tokenId);

        uint256 lotteryId = nftLotteries.listLottery(address(mockNFT), tokenId, betAmount, winProbability);
        (address _nftOwner, , , , ,) = nftLotteries.openLotteries(lotteryId);

        assertEq(nftOwner, _nftOwner);
        assertEq(mockNFT.ownerOf(tokenId), address(nftLotteries));
        vm.stopPrank();

        hoax(nftBetter);
        nftLotteries.placeBet{value: betAmount}(lotteryId);

        hoax(nftOwner);
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("BetIsPending()"))));
        nftLotteries.cancelLottery(lotteryId);
    }

    function testCanCancelLottery() public {
        startHoax(nftOwner);
        mockNFT.approve(address(nftLotteries), tokenId);

        uint256 lotteryId = nftLotteries.listLottery(address(mockNFT), tokenId, betAmount, winProbability);
        (address _nftOwner, , , , , bool _betIsPending) = nftLotteries.openLotteries(lotteryId);

        // Is owner and no pending bet
        assertEq(nftOwner, _nftOwner);
        assertEq(false, _betIsPending);

        vm.expectEmit(true, false, false, true);
        emit LotteryCancelled(
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

        assertEq(mockNFT.ownerOf(tokenId), address(nftLotteries));
        nftLotteries.cancelLottery(lotteryId);
        assertEq(mockNFT.ownerOf(tokenId), nftOwner);
    }

    /*//////////////////////////////////////////////////////////////
                                PLACE BET
    //////////////////////////////////////////////////////////////*/

    function testFuzzInvalidIdCannotPlaceBet(uint256 _fuzzLotteryId) public {
        // No lotteries currently exist
        assertEq(nftLotteries.nextLotteryId(), 1);

        vm.expectRevert(abi.encodePacked(bytes4(keccak256("WrongLotteryId()"))));
        nftLotteries.placeBet(_fuzzLotteryId);
    }

    function testBetIsPendingCannotPlaceBet() public {
        startHoax(nftOwner);
        mockNFT.approve(address(nftLotteries), tokenId);

        uint256 lotteryId = nftLotteries.listLottery(address(mockNFT), tokenId, betAmount, winProbability);
        vm.stopPrank();

        hoax(nftBetter, betAmount);
        nftLotteries.placeBet{value: betAmount}(lotteryId);

        hoax(address(1337), betAmount);
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("BetIsPending()"))));
        nftLotteries.placeBet{value: betAmount}(lotteryId);
    }

    function testFuzzInsufficientBetAmountCannotPlaceBet(uint256 _fuzzBetAmount) public {
        startHoax(nftOwner);
        mockNFT.approve(address(nftLotteries), tokenId);
        uint256 lotteryId = nftLotteries.listLottery(address(mockNFT), tokenId, betAmount, winProbability);
        vm.stopPrank();

        vm.assume(_fuzzBetAmount < betAmount);
        hoax(nftBetter, _fuzzBetAmount);
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("InsufficientFunds()"))));
        nftLotteries.placeBet{value: _fuzzBetAmount}(lotteryId);
    }

    function testFuzzRefundExtraETHAfterPlaceBet(uint256 _fuzzBetAmount) public {
        startHoax(nftOwner);
        mockNFT.approve(address(nftLotteries), tokenId);
        uint256 lotteryId = nftLotteries.listLottery(address(mockNFT), tokenId, betAmount, winProbability);
        vm.stopPrank();

        vm.assume(_fuzzBetAmount >= betAmount);
        hoax(nftBetter, _fuzzBetAmount);
        nftLotteries.placeBet{value: _fuzzBetAmount}(lotteryId);
        assertEq(nftBetter.balance, _fuzzBetAmount - betAmount);
    }

    function testBetPendingTrueAfterPlaceBet() public {
        startHoax(nftOwner);
        mockNFT.approve(address(nftLotteries), tokenId);
        uint256 lotteryId = nftLotteries.listLottery(address(mockNFT), tokenId, betAmount, winProbability);
        vm.stopPrank();

        (, , , , , bool _betIsPendingBefore) = nftLotteries.openLotteries(lotteryId);
        assertEq(_betIsPendingBefore, false);

        hoax(nftBetter, betAmount);
        nftLotteries.placeBet{value: betAmount}(lotteryId);

        (, , , , , bool _betIsPendingAfter) = nftLotteries.openLotteries(lotteryId);
        assertEq(_betIsPendingAfter, true);
    }

    function testRakeCollectedAfterPlaceBet() public {
        nftLotteries.setRake(5 * PERCENT_MULTIPLIER);
        deal(rakeRecipient, 0);

        startHoax(nftOwner);
        mockNFT.approve(address(nftLotteries), tokenId);
        uint256 lotteryId = nftLotteries.listLottery(address(mockNFT), tokenId, betAmount, winProbability);
        vm.stopPrank();

        hoax(nftBetter, betAmount);
        nftLotteries.placeBet{value: betAmount}(lotteryId);

        // 5% rake on 1 ether = 0.05 ether
        assertEq(rakeRecipient.balance, 0.05 ether);
    }

    function testFuzzRakeCollectedAfterPlaceBet(uint256 _fuzzRakePercent) public {
        vm.assume(_fuzzRakePercent < 100 * PERCENT_MULTIPLIER);
        nftLotteries.setRake(_fuzzRakePercent);
        deal(rakeRecipient, 0);

        startHoax(nftOwner);
        mockNFT.approve(address(nftLotteries), tokenId);
        uint256 lotteryId = nftLotteries.listLottery(address(mockNFT), tokenId, betAmount, winProbability);
        vm.stopPrank();

        hoax(nftBetter, betAmount);
        nftLotteries.placeBet{value: betAmount}(lotteryId);

        assertEq(rakeRecipient.balance, (betAmount * _fuzzRakePercent) / (100 * PERCENT_MULTIPLIER));
    }

    function testFuzzBetSentToNFTOwnerAfterPlaceBet(uint256 _fuzzBetAmount, uint256 _fuzzRakePercent) public {
        vm.assume(_fuzzBetAmount > 0 && _fuzzBetAmount < 2^256);
        vm.assume(_fuzzRakePercent < 100 * PERCENT_MULTIPLIER);
        nftLotteries.setRake(_fuzzRakePercent);
        deal(rakeRecipient, 0);

        startHoax(nftOwner, 0);
        mockNFT.approve(address(nftLotteries), tokenId);
        uint256 lotteryId = nftLotteries.listLottery(address(mockNFT), tokenId, _fuzzBetAmount, winProbability);
        vm.stopPrank();

        hoax(nftBetter, _fuzzBetAmount);
        nftLotteries.placeBet{value: _fuzzBetAmount}(lotteryId);

        uint256 rakeCollected = (_fuzzBetAmount * _fuzzRakePercent) / (100 * PERCENT_MULTIPLIER);

        assertEq(nftOwner.balance, _fuzzBetAmount - rakeCollected);
        assertEq(rakeRecipient.balance, rakeCollected);
    }
    
    function testFuzzSettleBetAfterPlaceBet(uint256 _fuzzWinProbability) public {
        vm.assume(_fuzzWinProbability > 0 && _fuzzWinProbability <= 100 * PERCENT_MULTIPLIER);

        startHoax(nftOwner);
        mockNFT.approve(address(nftLotteries), tokenId);
        uint256 lotteryId = nftLotteries.listLottery(address(mockNFT), tokenId, betAmount, _fuzzWinProbability);
        vm.stopPrank();

        vm.expectEmit(false, false, false, true);
        emit NewBet(
            NFTLotteries.Bet({
                lotteryId: lotteryId,
                user: nftBetter
            })
        );

        hoax(nftBetter, betAmount);
        uint256 requestId = nftLotteries.placeBet{value: betAmount}(lotteryId);

        (uint256 _lotteryId, address _user) = nftLotteries.vrfRequestIdToBet(requestId);
        assertEq(lotteryId, _lotteryId);
        assertEq(nftBetter, _user);

        // Mimic VRF mock random number
        uint256 randomNumber = uint256(keccak256(abi.encode(requestId, 0))) % (100 * PERCENT_MULTIPLIER + 1);
        // Mimic settling bet (reference _settleBet function)
        bool win;
        if (randomNumber <= _fuzzWinProbability) {
            win = true;
        } else {
            win = false;
        }

        // Note: betIsPending always true because _settleBet emits outdated Lottery instance from memory to save gas
        vm.expectEmit(true, false, false, true);
        emit BetSettled(
            win, 
            NFTLotteries.Bet({
                lotteryId: lotteryId,
                user: nftBetter
            }), 
            NFTLotteries.Lottery({
                nftOwner: nftOwner,
                nftCollection: mockNFT,
                tokenId: tokenId,
                betAmount: betAmount,
                winProbability: _fuzzWinProbability,
                betIsPending: true
            }) 
        );

        // Mimic fulfilling VRF randomness call -> _settleBet with mock
        mockCoordinator.fulfillRandomWords(requestId, address(nftLotteries));

        if (win) {
            assertEq(mockNFT.ownerOf(tokenId), nftBetter);
        } else {
            (address _nftOwner, , , , , bool _betIsPending) = nftLotteries.openLotteries(lotteryId);

            // Verify betIsPending updated after lost lottery settled
            assertEq(false, _betIsPending);
            assertEq(nftOwner, _nftOwner);
            assertEq(mockNFT.ownerOf(tokenId), address(nftLotteries));
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 SETTERS
    //////////////////////////////////////////////////////////////*/

    function testNonOwnerCannotSetKeyHash() public {
        hoax(address(1337));
        vm.expectRevert("UNAUTHORIZED");
        nftLotteries.setKeyHash(bytes32("test"));
    }

    function testCanSetKeyHash() public {
        hoax(OWNER);
        nftLotteries.setKeyHash(bytes32("test"));
        assertEq(nftLotteries.keyHash(), bytes32("test"));
    }

    function testNonOwnerCannotSetSubscriptionId() public {
        hoax(address(1337));
        vm.expectRevert("UNAUTHORIZED");
        nftLotteries.setSubscriptionId(uint64(69));
    }

    function testCanSetSubscriptionId() public {
        hoax(OWNER);
        nftLotteries.setSubscriptionId(uint64(69));
        assertEq(nftLotteries.subscriptionId(), uint64(69));
    }

    function testNonOwnerCannotSetCallbackGasLimit() public {
        hoax(address(1337));
        vm.expectRevert("UNAUTHORIZED");
        nftLotteries.setCallbackGasLimit(uint32(69));
    }

    function testCanSetCallbackGasLimit() public {
        hoax(OWNER);
        nftLotteries.setCallbackGasLimit(uint32(69));
        assertEq(nftLotteries.callbackGasLimit(), uint32(69));
    }

    function testNonOwnerCannotSetRequestConfirmations() public {
        hoax(address(1337));
        vm.expectRevert("UNAUTHORIZED");
        nftLotteries.setRequestConfirmations(uint16(69));
    }

    function testCanSetRequestConfirmations() public {
        hoax(OWNER);
        nftLotteries.setRequestConfirmations(uint16(69));
        assertEq(nftLotteries.requestConfirmations(), uint16(69));
    }

    function testNonOnwerCannotSetRake() public {
        hoax(address(1337));
        vm.expectRevert("UNAUTHORIZED");
        nftLotteries.setRake(0);
    }

    function testFuzzInvalidPercentCannotSetRake(uint256 _fuzzRake) public {
        vm.assume(_fuzzRake > 100 * PERCENT_MULTIPLIER);
        hoax(OWNER);
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("InvalidPercent()"))));
        nftLotteries.setRake(_fuzzRake);
    }

    function testFuzzCanSetRake(uint256 _fuzzRake) public {
        vm.assume(_fuzzRake < 100 * PERCENT_MULTIPLIER);
        hoax(OWNER);
        nftLotteries.setRake(_fuzzRake);
        assertEq(nftLotteries.rake(), _fuzzRake);
    }

    function testNonOwnerCannotSetRakeRecipient() public {
        hoax(address(1337));
        vm.expectRevert("UNAUTHORIZED");
        nftLotteries.setRakeRecipient(address(42));
    }

    function testCannotSetZeroAddressSetRakeRecipient() public {
        hoax(OWNER);
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("InvalidAddress()"))));
        nftLotteries.setRakeRecipient(address(0));
    }

    function testCannotSetSameRecipientSetRakeRecipient() public {
        hoax(OWNER);
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("InvalidAddress()"))));
        nftLotteries.setRakeRecipient(rakeRecipient);
    }

    function testCanSetRakeRecipient() public {
        hoax(OWNER);
        nftLotteries.setRakeRecipient(address(42));
        assertEq(nftLotteries.rakeRecipient(), address(42));
    }

    function testNonOwnerCannotSetPendingBetStatusToFalse() public {
        startHoax(nftOwner);
        mockNFT.approve(address(nftLotteries), tokenId);
        uint256 lotteryId = nftLotteries.listLottery(address(mockNFT), tokenId, betAmount, winProbability);
        vm.stopPrank();

        hoax(address(1337));
        vm.expectRevert("UNAUTHORIZED");
        nftLotteries.setPendingBetStatusToFalse(lotteryId);
    }

    function testCanSetPendingBetStatusToFalse() public {
        startHoax(nftOwner);
        mockNFT.approve(address(nftLotteries), tokenId);
        uint256 lotteryId = nftLotteries.listLottery(address(mockNFT), tokenId, betAmount, winProbability);
        vm.stopPrank();

        hoax(nftBetter);
        nftLotteries.placeBet{value: betAmount}(lotteryId);

        (, , , , , bool _betIsPendingBefore) = nftLotteries.openLotteries(lotteryId);
        assertEq(true, _betIsPendingBefore);

        hoax(OWNER);
        nftLotteries.setPendingBetStatusToFalse(lotteryId);

        (, , , , , bool _betIsPendingAfter) = nftLotteries.openLotteries(lotteryId);
        assertEq(false, _betIsPendingAfter);
    }

    function testCannotSetZeroBetAmountSetBetAmount() public {
        startHoax(nftOwner);
        mockNFT.approve(address(nftLotteries), tokenId);
        uint256 lotteryId = nftLotteries.listLottery(address(mockNFT), tokenId, betAmount, winProbability);
        vm.stopPrank();

        hoax(nftOwner);
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("BetAmountZero()"))));
        nftLotteries.setBetAmount(lotteryId, 0);
    }

    function testBetIsPendingCannotSetBetAmount() public {
        startHoax(nftOwner);
        mockNFT.approve(address(nftLotteries), tokenId);
        uint256 lotteryId = nftLotteries.listLottery(address(mockNFT), tokenId, betAmount, winProbability);
        vm.stopPrank();

        hoax(nftBetter);
        nftLotteries.placeBet{value: betAmount}(lotteryId);

        hoax(nftOwner);
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("BetIsPending()"))));
        nftLotteries.setBetAmount(lotteryId, betAmount + 0.5 ether);
    }

    function testNonOwnerCannotSetBetAmount() public {
        startHoax(nftOwner);
        mockNFT.approve(address(nftLotteries), tokenId);
        uint256 lotteryId = nftLotteries.listLottery(address(mockNFT), tokenId, betAmount, winProbability);
        vm.stopPrank();

        vm.expectRevert(abi.encodePacked(bytes4(keccak256("Unauthorized()"))));
        nftLotteries.setBetAmount(lotteryId, betAmount + 1 ether);
    }

    function testFuzzCanSetBetAmount(uint256 _fuzzBetAmount) public {
        startHoax(nftOwner);
        mockNFT.approve(address(nftLotteries), tokenId);
        uint256 lotteryId = nftLotteries.listLottery(address(mockNFT), tokenId, betAmount, winProbability);
        vm.stopPrank();

        (, , , uint256 _betAmountBefore, , ) = nftLotteries.openLotteries(lotteryId);
        assertEq(betAmount, _betAmountBefore);

        vm.assume(_fuzzBetAmount > 0);
        hoax(nftOwner);
        nftLotteries.setBetAmount(lotteryId, _fuzzBetAmount);

        (, , , uint256 _betAmountAfter, ,) = nftLotteries.openLotteries(lotteryId);
        assertEq(_fuzzBetAmount, _betAmountAfter);
    }

    function testCannotSetZeroWinProbabilitySetWinProbability() public {
        startHoax(nftOwner);
        mockNFT.approve(address(nftLotteries), tokenId);
        uint256 lotteryId = nftLotteries.listLottery(address(mockNFT), tokenId, betAmount, winProbability);
        vm.stopPrank();

        hoax(nftOwner);
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("InvalidPercent()"))));
        nftLotteries.setWinProbability(lotteryId, 0);
    }

    function testFuzzCannotSetAboveHundredSetWinProbability(uint256 _fuzzWinProbability) public {
        startHoax(nftOwner);
        mockNFT.approve(address(nftLotteries), tokenId);
        uint256 lotteryId = nftLotteries.listLottery(address(mockNFT), tokenId, betAmount, winProbability);
        vm.stopPrank();

        vm.assume(_fuzzWinProbability > 100 * PERCENT_MULTIPLIER);
        hoax(nftOwner);
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("InvalidPercent()"))));
        nftLotteries.setWinProbability(lotteryId, _fuzzWinProbability);
    }

    function testBetIsPendingCannotSetWinProbability() public {
        startHoax(nftOwner);
        mockNFT.approve(address(nftLotteries), tokenId);
        uint256 lotteryId = nftLotteries.listLottery(address(mockNFT), tokenId, betAmount, winProbability);
        vm.stopPrank();

        hoax(nftBetter);
        nftLotteries.placeBet{value: betAmount}(lotteryId);

        hoax(nftOwner);
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("BetIsPending()"))));
        nftLotteries.setWinProbability(lotteryId, 50 * PERCENT_MULTIPLIER);
    }

    function testNonOwnerCannotSetWinProbability() public {
        startHoax(nftOwner);
        mockNFT.approve(address(nftLotteries), tokenId);
        uint256 lotteryId = nftLotteries.listLottery(address(mockNFT), tokenId, betAmount, winProbability);
        vm.stopPrank();

        vm.expectRevert(abi.encodePacked(bytes4(keccak256("Unauthorized()"))));
        nftLotteries.setWinProbability(lotteryId, 50 * PERCENT_MULTIPLIER);
    }

    function testFuzzCanSetWinProbability(uint256 _fuzzWinProbability) public {
        startHoax(nftOwner);
        mockNFT.approve(address(nftLotteries), tokenId);
        uint256 lotteryId = nftLotteries.listLottery(address(mockNFT), tokenId, betAmount, winProbability);
        vm.stopPrank();

        (, , , , uint256 _winProbabilityBefore, ) = nftLotteries.openLotteries(lotteryId);
        assertEq(winProbability, _winProbabilityBefore);

        vm.assume(_fuzzWinProbability > 0 && _fuzzWinProbability < 100 * PERCENT_MULTIPLIER);
        hoax(nftOwner);
        nftLotteries.setWinProbability(lotteryId, _fuzzWinProbability);

        (, , , , uint256 _winProbabilityAfter, ) = nftLotteries.openLotteries(lotteryId);
        assertEq(_fuzzWinProbability, _winProbabilityAfter);
    }
}