// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";

contract TestVRF is VRFConsumerBaseV2 {
    VRFCoordinatorV2Interface COORDINATOR;
    LinkTokenInterface LINKTOKEN;
    uint64 public subscriptionId;
    uint256 public requestId;
    uint256[] public randomWords;

    constructor(
        address vrfCoordinator,
        address link
    ) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        subscriptionId = COORDINATOR.createSubscription();
        COORDINATOR.addConsumer(subscriptionId, address(this));
        LINKTOKEN = LinkTokenInterface(link);
    }

    function cancelSubscription() external {
        COORDINATOR.cancelSubscription(subscriptionId, msg.sender);
    }

    function fund(uint256 amount) public {
        LINKTOKEN.transferAndCall(
            address(COORDINATOR),
            amount,
            abi.encode(subscriptionId)
        );
    }

    function randomnessIsRequestedHere() public {
        uint256 requestId_ = COORDINATOR.requestRandomWords(
            0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f,
            subscriptionId,
            3,
            2_500_000,
            1
        );
        requestId = requestId_;
    }

    function fulfillRandomWords(
        uint256,
        uint256[] memory randomWords_
    ) internal override {
        randomWords = randomWords_;
    }
}
