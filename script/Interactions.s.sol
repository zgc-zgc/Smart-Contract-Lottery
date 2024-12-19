//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DeployLottery} from "./DeployLottery.s.sol";
import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {console2} from "forge-std/console2.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

/**
 * @dev Advances block number to prevent arithmetic overflow
 * Due to SubscriptionApi.sol's implementation, block.number must be
 * greater than 0 to safely generate subscription IDs in local testing.
 * We use vm.roll(block.number + 1) to achieve this.
 */
contract CreateSubscription is Script {
    function createSubscriptionUsingConfig(HelperConfig.NetworkConfig memory _networkConfig)
        public
        returns (uint256 subscriptionId)
    {
        HelperConfig.NetworkConfig memory networkConfig = _networkConfig;
        address vrfCoordinator = networkConfig.vrfCoordinator;
        vm.startBroadcast(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);
        subscriptionId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
    }

    function run() external {}
}

/**
 * @dev The FUND_ETHER should not be too small
 */
contract FundSubscription is Script {
    uint256 private constant FUND_ETHER = 500 ether;
    uint256 private constant STARTING_USER_BALANCE = 1000 ether;
    uint256 private constant LOCAL_CHAIN_ID = 31337;

    function FundSubscriptionUsingConfig(HelperConfig.NetworkConfig memory _networkConfig) public {
        HelperConfig.NetworkConfig memory networkConfig = _networkConfig;
        address vrfCoordinator = networkConfig.vrfCoordinator;
        uint256 subscriptionId = networkConfig.subscriptionId;
        address linkToken = networkConfig.linkToken;
        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);
            LinkToken(linkToken).mint(address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266), STARTING_USER_BALANCE);
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_ETHER);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_ETHER, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }

    function run() external {}
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address mostRecentlyDeployed, HelperConfig.NetworkConfig memory _networkConfig)
        public
    {
        HelperConfig.NetworkConfig memory networkConfig = _networkConfig;
        address vrfCoordinator = networkConfig.vrfCoordinator;
        uint256 subscriptionId = networkConfig.subscriptionId;
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subscriptionId, mostRecentlyDeployed);
        vm.stopBroadcast();
    }

    function run() external {}
}
