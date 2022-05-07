// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.12;

import { NFTLotteries } from "../NFTLotteries.sol";
import { MockERC721 } from "solmate/test/utils/mocks/MockERC721.sol";
import { VRFCoordinatorV2Mock } from "chainlink/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import  "forge-std/Test.sol";

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

    /// @notice Test NFTLotteries Constructor
    function testConstructor() public {
        // Exepct Revert with invalid coordinator address
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("InvalidAddress()"))));
        nftLotteries = new NFTLotteries(
            subscriptionId,
            address(0),
            keyHash,
            rake,
            rakeRecipient
        );

        // Exepct Revert with invalid rake amount (over 100%)
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("InvalidPercent()"))));
        nftLotteries = new NFTLotteries(
            subscriptionId,
            address(mockCoordinator),
            keyHash,
            100000001,
            rakeRecipient
        );

        // Exepct Revert with invalid rake recipient
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("InvalidAddress()"))));
        nftLotteries = new NFTLotteries(
            subscriptionId,
            address(mockCoordinator),
            keyHash,
            rake,
            address(0)
        );
    }
}
