// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

import "forge-std/Script.sol";
import { NFTLotteries } from "src/NFTLotteries.sol";

contract Deploy is Script {
    function run() external {
        uint64 subscriptionId = uint64(vm.envUint("GOERLI_SUB_ID"));
        address vrfCoordinator = vm.envAddress("GOERLI_VRF_COORDINATOR");
        bytes32 keyHash = vm.envBytes32("GOERLI_KEY_HASH");
        uint256 rake = vm.envUint("GOERLI_RAKE");
        address rakeRecipient = vm.envAddress("GOERLI_RAKE_RECIPIENT");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        NFTLotteries nftLotteries = new NFTLotteries(
            subscriptionId,
            vrfCoordinator,
            keyHash,
            rake,
            rakeRecipient
        );

        vm.stopBroadcast();
    }
}