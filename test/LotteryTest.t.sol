//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console2} from "forge-std/Test.sol";
import {DeployLottery} from "../script/DeployLottery.s.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract LotteryTest is Test {
    /////////////////////////////////////////////
    ////////////    STATE VARIABLES   ///////////
    /////////////////////////////////////////////
    Raffle public raffle;
    HelperConfig.NetworkConfig networkConfig;
    uint256 public constant STARTING_BALANCE = 100 ether;
    address payable[] public players = new address payable[](10);
    uint256 public requestId;

    /////////////////////////////////////////////
    ///////////////    SETUP    ////////////////
    /////////////////////////////////////////////
    function setUp() public {
        DeployLottery deployLottery = new DeployLottery();
        (raffle, networkConfig) = deployLottery.run();
        vm.deal(address(networkConfig.vrfCoordinator), STARTING_BALANCE);
        for (uint256 i = 0; i < players.length; i++) {
            players[i] = payable(makeAddr(string(abi.encodePacked("player", i))));
            vm.deal(players[i], STARTING_BALANCE);
        }
    }

    /////////////////////////////////////////////
    //////////////   MODIFIERS   ///////////////
    /////////////////////////////////////////////
    modifier tenEnteredRaffle() {
        for (uint256 i = 0; i < players.length; i++) {
            vm.prank(players[i]);
            raffle.enterRaffle{value: networkConfig.entranceFee}();
        }
        _;
    }

    modifier AfterRandomNumRequested() {
        vm.warp(block.timestamp + networkConfig.interval + 1);
        vm.roll(block.number + 1);
        vm.recordLogs();
        raffle.performUpkeep("");

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestIdEventSelector = keccak256("RequestIdGenerated(uint256)");

        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == requestIdEventSelector) {
                requestId = uint256(entries[i].topics[1]);
                break;
            }
        }
        _;
    }

    /////////////////////////////////////////////
    ////////   RAFFLE ENTRANCE TESTS    ////////
    /////////////////////////////////////////////
    function test_enterRaffle_Success_WhenEnoughFee() public tenEnteredRaffle {
        assert(raffle.getPlayersLength() == players.length);
        assert(raffle.getRecentWinner() == address(0));
    }

    function test_enterRaffle_EmitsEvent_WhenPlayerEnters() public {
        vm.recordLogs();
        vm.prank(players[0]);
        raffle.enterRaffle{value: networkConfig.entranceFee}();

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assert(entries.length == 1);
        assert(entries[0].topics[0] == keccak256("RaffleEntered(address)"));
        assert(entries[0].topics[1] == bytes32(uint256(uint160(address(players[0])))));
    }

    function test_enterRaffle_Reverts_WhenNotEnoughFee() public {
        vm.expectRevert();
        raffle.enterRaffle{value: 0.001 ether}();
    }

    function test_enterRaffle_Reverts_WhenRaffleCalculating() public tenEnteredRaffle {
        vm.warp(block.timestamp + networkConfig.interval + 1);
        raffle.performUpkeep("");
        vm.expectRevert();
        raffle.enterRaffle{value: networkConfig.entranceFee}();
    }

    /////////////////////////////////////////////
    //////////   CHECKUPKEEP TESTS    //////////
    /////////////////////////////////////////////
    function test_checkUpkeep_ReturnsFalse_WhenNoBalance() public {
        vm.warp(block.timestamp + networkConfig.interval + 1);
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function test_checkUpkeep_ReturnsFalse_WhenNotEnoughTimePassed() public tenEnteredRaffle {
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function test_checkUpkeep_ReturnsTrue_WhenParametersGood() public tenEnteredRaffle {
        vm.warp(block.timestamp + networkConfig.interval + 1);
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(upkeepNeeded);
    }

    /////////////////////////////////////////////
    ////////   PERFORMUPKEEP TESTS    //////////
    /////////////////////////////////////////////
    function test_performUpkeep_Reverts_WhenCheckUpkeepFalse() public {
        uint256 balance = 0;
        uint256 playersLength = 0;
        uint256 raffleState = uint256(Raffle.RaffleState.OPEN);

        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                balance,
                playersLength,
                raffleState,
                block.timestamp,
                raffle.getLastTimeStamp(),
                networkConfig.interval
            )
        );
        raffle.performUpkeep("");
    }

    /////////////////////////////////////////////
    ///////   FULFILLRANDOMWORDS TESTS   ///////
    /////////////////////////////////////////////
    function test_fulfillRandomWords_PicksWinner_WhenCalled() public tenEnteredRaffle {
        vm.warp(block.timestamp + networkConfig.interval + 1);
        vm.roll(block.number + 1);
        vm.recordLogs();
        raffle.performUpkeep("");

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestIdEventSelector = keccak256("RequestIdGenerated(uint256)");

        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == requestIdEventSelector) {
                requestId = uint256(entries[i].topics[1]);
                break;
            }
        }

        VRFCoordinatorV2_5Mock(networkConfig.vrfCoordinator).fulfillRandomWords(requestId, address(raffle));

        assert(raffle.getRecentWinner() != address(0));
    }

    function test_fulfillRandomWords_EmitsEvent_WhenWinnerPicked() public tenEnteredRaffle AfterRandomNumRequested {
        vm.recordLogs();
        VRFCoordinatorV2_5Mock(networkConfig.vrfCoordinator).fulfillRandomWords(requestId, address(raffle));
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 winnerinEvent;
        bytes32 timestampinEvent;
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("WinnerPicked(address,uint256)")) {
                winnerinEvent = entries[i].topics[1];
                timestampinEvent = entries[i].topics[2];
                break;
            }
        }
        assert(winnerinEvent == bytes32(uint256(uint160(raffle.getRecentWinner()))));
        assert(timestampinEvent == bytes32(uint256(raffle.getLastTimeStamp())));
    }

    function test_fulfillRandomWords_Reverts_WhenTransferFails() public {
        address payable invalidWinner = payable(address(new RevertingContract()));
        vm.deal(invalidWinner, STARTING_BALANCE);
        vm.prank(invalidWinner);
        raffle.enterRaffle{value: networkConfig.entranceFee}();
        vm.warp(block.timestamp + networkConfig.interval + 1);
        vm.roll(block.number + 1);
        vm.recordLogs();
        raffle.performUpkeep("");

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestIdEventSelector = keccak256("RequestIdGenerated(uint256)");

        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == requestIdEventSelector) {
                requestId = uint256(entries[i].topics[1]);
                break;
            }
        }
        // vm.expectRevert(Raffle.Raffle__TransferFailed.selector);
        // VRFCoordinatorV2_5Mock(networkConfig.vrfCoordinator).fulfillRandomWords(requestId, address(raffle));
        vm.prank(address(networkConfig.vrfCoordinator));
        vm.expectRevert(Raffle.Raffle__TransferFailed.selector);
        raffle.rawFulfillRandomWords(requestId, new uint256[](1));
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep() public tenEnteredRaffle {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(networkConfig.vrfCoordinator).fulfillRandomWords(0, address(raffle));
    }
}

/////////////////////////////////////////////
//////////   HELPER CONTRACTS    ////////////
/////////////////////////////////////////////
contract RevertingContract {
    receive() external payable {
        revert();
    }
}
