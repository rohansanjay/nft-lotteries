// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.12;

import {NFTLottery} from "../NFTLottery.sol";
import {DSTestPlus} from "./utils/DSTestPlus.sol";
import "forge-std/console.sol";

contract NFTLotteryTest is DSTestPlus {
    NFTLottery nftLottery;

    function setUp() public {
        console.log("Testing...");
    }
}
