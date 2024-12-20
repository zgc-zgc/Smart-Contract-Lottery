//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {console2} from "forge-std/console2.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

abstract contract HelperConfigConstants {
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    uint96 public MOCK_BASE_FEE = 0.25 ether;
    uint96 public MOCK_GAS_PRICE_LINK = 1e9;
    int256 public MOCK_WEI_PER_UINT_LINK = 4e15;
}

contract HelperConfig is Script, HelperConfigConstants {
    NetworkConfig public activeNetwork;

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address linkToken;
        address account;
    }

    constructor() {
        if (block.chainid == ETH_SEPOLIA_CHAIN_ID) {
            activeNetwork = getSepoliaEthConfig();
        } else {
            activeNetwork = getORcreateAnvilEthConfig();
        }
    }

    function getActiveNetworkConfig() external view returns (NetworkConfig memory) {
        return activeNetwork;
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory sepoliaConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30 seconds,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 0,
            callbackGasLimit: 500000,
            linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: 0x51eD19819B5a960B4B3aDfeDEedCeCaB51953010 //A known address with test tokens
        });
        return sepoliaConfig;
    }

    function getORcreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetwork.vrfCoordinator != address(0)) {
            return activeNetwork;
        } //if already set, return the activeNetwork
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorV2_5Mock =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UINT_LINK);
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();
        NetworkConfig memory anvilConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 31 seconds,
            vrfCoordinator: address(vrfCoordinatorV2_5Mock),
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 0,
            callbackGasLimit: 500000,
            linkToken: address(linkToken),
            account: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        });
        return anvilConfig;
    }
}
