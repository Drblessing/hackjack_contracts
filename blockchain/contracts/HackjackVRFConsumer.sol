// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

// Debugging
import "hardhat/console.sol";

// VRF
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "./BreakdownUint256.sol";
import "./Destructible.sol";



contract HackjackVRFConsumer is VRFConsumerBaseV2, BreakdownUint256, Destructible { 
    VRFCoordinatorV2Interface COORDINATOR;
    uint64 subscriptionId;
    address vrfCoordinator = 0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed;
    bytes32 keyHash =
        0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f;
    uint32 callbackGasLimit = 2500000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 1;
    uint256[] public s_randomWords;
    uint256 public s_requestId;
    address s_owner;
    uint8[] public fulfilledRandomUint8;

    constructor() VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_owner = msg.sender;
        subscriptionId = 1327;
    }

    function requestRandomWords() external onlyOwner {
        // Will revert if subscription is not set and funded.
        s_requestId = COORDINATOR.requestRandomWords(
            keyHash,    
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
    }

    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        s_randomWords = randomWords;
        fulfilledRandomUint8 = getUint256BrokenIntoUint8(s_randomWords[0]);
        
    }
}