//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Raffle} from "../src/Raffle.sol";
import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";
import {console2} from "forge-std/console2.sol";

contract DeployLottery is Script {
    Raffle public raffle;
    HelperConfig public helperConfig;

    address vrfCoordinator;
    uint256 subscriptionId;
    uint256 entranceFee;
    uint256 interval;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    address linkToken;

    function run() external returns (Raffle, HelperConfig.NetworkConfig memory) {
        helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getActiveNetworkConfig();

        //subscription
        if (subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            subscriptionId = createSubscription.createSubscriptionUsingConfig(networkConfig);
            //Update subscriptionId in networkConfig
            networkConfig.subscriptionId = subscriptionId;
        }
        //Fund My Subscription
        FundSubscription fundSubscription = new FundSubscription();
        fundSubscription.FundSubscriptionUsingConfig(networkConfig);

        vm.startBroadcast(networkConfig.account);
        raffle = new Raffle(
            networkConfig.entranceFee,
            networkConfig.interval,
            networkConfig.vrfCoordinator,
            networkConfig.gasLane,
            networkConfig.subscriptionId,
            networkConfig.callbackGasLimit
        );
        vm.stopBroadcast();

        // Add Consumer
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumerUsingConfig(address(raffle), networkConfig);
        return (raffle, networkConfig);
    }
}
