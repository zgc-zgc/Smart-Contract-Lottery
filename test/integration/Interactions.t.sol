//SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

import {Test, console2} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployLottery} from "../../script/DeployLottery.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "../../script/Interactions.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Vm} from "forge-std/Vm.sol";

contract InteractionsTest is Test {
    Raffle public raffle;
    HelperConfig.NetworkConfig public networkConfig;
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    address public constant USER = address(1);
    uint256 public requestId;

    function setUp() public {
        // 1. Deploy contracts and configurations
        DeployLottery deployLottery = new DeployLottery();
        (raffle, networkConfig) = deployLottery.run();

        // 2. Setup test accounts
        vm.deal(USER, STARTING_USER_BALANCE);
    }

    // Test full deployment process
    function testFullDeploymentProcess() public view {
        // 1. Verify contract deployment
        assertTrue(address(raffle) != address(0), "Raffle not deployed");

        // 2. Verify subscription creation
        assertTrue(networkConfig.subscriptionId != 0, "Subscription not created");

        // 3. Verify consumer addition
        if (block.chainid == 31337) {
            bool isConsumer = VRFCoordinatorV2_5Mock(networkConfig.vrfCoordinator).consumerIsAdded(
                networkConfig.subscriptionId, address(raffle)
            );
            assertTrue(isConsumer, "Consumer not added");
        }
    }

    // Test complete raffle flow
    function testCompleteRaffleFlow() public skipFork {
        // 1. User enters raffle
        vm.startPrank(USER);
        raffle.enterRaffle{value: networkConfig.entranceFee}();
        vm.stopPrank();

        // 2. Verify player entry
        assertEq(raffle.getPlayersLength(), 1, "Player not entered");

        // 3. Trigger raffle
        vm.warp(block.timestamp + networkConfig.interval + 1);
        vm.roll(block.number + 1);

        // 4. Execute performUpkeep
        vm.recordLogs();
        raffle.performUpkeep("");
        assertEq(uint256(raffle.getRaffleState()), 1, "Raffle not calculating");

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestIdEventSelector = keccak256("RequestIdGenerated(uint256)");

        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == requestIdEventSelector) {
                requestId = uint256(entries[i].topics[1]);
                break;
            }
        }
        // 5. Simulate VRF response
        if (block.chainid == 31337) {
            VRFCoordinatorV2_5Mock(networkConfig.vrfCoordinator).fulfillRandomWords(requestId, address(raffle));
        } else {
            // Create random words array
            uint256[] memory randomWords = new uint256[](1);
            randomWords[0] = uint256(keccak256(abi.encode(block.timestamp))); // Generate a random number

            // Call rawFulfillRandomWords correctly
            raffle.rawFulfillRandomWords(requestId, randomWords);
        }

        // 6. Verify winner
        address winner = raffle.getRecentWinner();
        assertTrue(winner != address(0), "No winner picked");
        assertEq(winner, USER, "Wrong winner");
        assertEq(uint256(raffle.getRaffleState()), 0, "Raffle state is not open");
        assertEq(raffle.getPlayersLength(), 0, "Players length is not 0");
        assertEq(address(raffle).balance, 0, "Balance is not 0");
    }

    // Skip tests on non-local networks
    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }
}
