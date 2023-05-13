// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";

contract Constants {
    mapping(string => Config) internal configMap;
    struct Config {
        VRFCoordinatorV2Interface vrfCoordinator;
        LinkTokenInterface linkToken;
        bytes32 keyHash;
        uint32 callbackGasLimit;
        uint16 requestConfirmations;
        uint32 numWords;
    }

    constructor() {
        Config memory mumbai = Config(
            VRFCoordinatorV2Interface(
                0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed
            ),
            LinkTokenInterface(0x326C977E6efc84E512bB9C30f76E30c160eD06FB),
            0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f,
            2500000,
            3,
            1
        );

        Config memory sepolia = Config(
            VRFCoordinatorV2Interface(
                0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
            ),
            LinkTokenInterface(0x779877A7B0D9E8603169DdbD7836e478b4624789),
            0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            100000,
            3,
            2
        );

        configMap["mumbai"] = mumbai;
        configMap["sepolia"] = sepolia;
    }
}
