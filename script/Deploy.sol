// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

import "forge-std/Script.sol";
import { NFTLotteries } from "src/NFTLotteries.sol";

contract Deploy is Script {
    function run(
        uint64 _subscriptionId, 
        address _vrfCoordinator, 
        bytes32 _keyHash,
        uint256 _rake,
        address _rakeRecipient
    ) external {
        vm.startBroadcast();



        NFTLotteries nftLotteries = new NFTLotteries(
            _subscriptionId,
            _vrfCoordinator,
            _keyHash,
            _rake,
            _rakeRecipient
        );

        vm.stopBroadcast();
    }
}