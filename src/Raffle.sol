//SPDX-License-Identifier:MIT

pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from
    "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";

/**
 * @title A sample Raffle Contract
 * @author RealGC
 * @notice This contract is using for creating a sample Raffle
 * @dev https://github.com/zgc-zgc/Smart-Contract-Lottery.git
 */
contract Raffle is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    /* Errors */
    error Raffle__NotEnoughEntranceFees();
    error Raffle__NotOpen();
    error Raffle__TransferFailed();
    error Raffle__UpkeepNotNeeded(
        uint256 balance,
        uint256 playersLength,
        RaffleState raffleState,
        uint256 timestamp,
        uint256 lastTimeStamp,
        uint256 interval
    );

    /* Type declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /* Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner, uint256 indexed timestamp);
    event RequestIdGenerated(uint256 indexed requestId);
    /* State variables */
    // Constants

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    // Immutable variables
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    // Storage variables
    uint256 private s_lastTimeStamp;
    address payable[] private s_players;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /* Functions */
    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    /* External Functions */
    function performUpkeep(bytes calldata /* performData */ ) external {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance, s_players.length, s_raffleState, block.timestamp, s_lastTimeStamp, i_interval
            );
        }
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );
        emit RequestIdGenerated(requestId);
    }

    function getEntranceFees() external view returns (uint256) {
        return i_entranceFee;
    }

    /* Public Functions */
    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEntranceFees();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    /**
     * @dev This is the function that Chainlink Automation will call to check if it's time to perform the upkeep.
     * checkData The data passed to the function when the upkeep was registered.
     * @return upkeepNeeded Whether the upkeep is needed.
     * @return performData The data to pass to the performUpkeep function.
     */
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, "");
    }

    /* Internal Functions */
    function fulfillRandomWords(uint256, /* requestId */ uint256[] calldata randomWords) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
        emit WinnerPicked(recentWinner, s_lastTimeStamp);
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }
    /* Getter Functions */

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getPlayersLength() public view returns (uint256) {
        return s_players.length;
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    /* Receive & Fallback */
    receive() external payable {
        enterRaffle();
    }

    fallback() external payable {
        enterRaffle();
    }
}
