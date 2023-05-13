// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";

contract Crash is VRFConsumerBaseV2, Ownable {
    // Sepolia
    VRFCoordinatorV2Interface COORDINATOR =
        VRFCoordinatorV2Interface(0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625);
    LinkTokenInterface LINKTOKEN =
        LinkTokenInterface(0x779877A7B0D9E8603169DdbD7836e478b4624789);

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    bytes32 keyHash =
        0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;

    // A reasonable default is 100000, but this value could be different
    // on other networks.
    uint32 callbackGasLimit = 100000;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 numWords = 2;

    // Storage parameters
    uint256[] public s_randomWords;
    uint256 public s_requestId;
    uint64 public s_subscriptionId = 662;
    uint public crashNumber;

    // Crash
    // Enum game state
    enum GameState {
        DORMANT,
        BETTING_OPEN,
        REQUESTING_RANDOM_NUMBER,
        REVEALING
    }

    // Player state
    enum PlayerState {
        NOT_PLAYING,
        PLAYING
    }

    struct Player {
        address playerAddress;
        uint256 betAmount;
        uint256 betNumber;
    }

    GameState public gameState;
    mapping(address => PlayerState) public playerState;
    mapping(address => Player) public players;

    // Events
    event BetPlaced(
        address playerAddress,
        uint256 betAmount,
        uint256 betNumber
    );
    event BetRevealed(
        address playerAddress,
        uint256 betAmount,
        uint256 betNumber,
        uint256 randomNumber
    );
    event BetLost(
        address playerAddress,
        uint256 betAmount,
        uint256 betNumber,
        uint256 randomNumber
    );
    event BetWon(
        address playerAddress,
        uint256 betAmount,
        uint256 betNumber,
        uint256 randomNumber
    );

    // Constructor

    constructor()
        VRFConsumerBaseV2(0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625)
    {
        //Create a new subscription when you deploy the contract.
    }

    // Assumes the subscription is funded sufficiently.
    function requestRandomWords() public {
        // Will revert if subscription is not set and funded.
        s_requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
    }

    uint256 private constant MAX_UINT256 = 2 ** 256 - 1;

    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] memory randomWords
    ) internal override {
        s_randomWords = randomWords;
        // Turn randomWords[0] into a number between 1 and 100
        uint256 normalized = (randomWords[0] * 1e18) / MAX_UINT256;
        uint256 exponent = 100 - (uint256(100 * (normalized * 2302585)) / 1e18);
        crashNumber = exponent < 1 ? 1 : (exponent > 100 ? 100 : exponent);
    }

    // Start the game
    function startGame() public onlyOwner {
        gameState = GameState.BETTING_OPEN;
    }

    // Stop the game
    function stopGame() public onlyOwner {
        gameState = GameState.DORMANT;
    }

    // Place a bet
    function placeBet(uint256 betNumber) public payable {
        require(
            gameState == GameState.BETTING_OPEN,
            "Betting is not open at the moment"
        );
        require(
            playerState[msg.sender] == PlayerState.NOT_PLAYING,
            "You are already playing"
        );
        require(
            betNumber > 0 && betNumber <= 100,
            "Bet number must be between 1 and 100"
        );
        require(msg.value > 0, "Bet amount must be greater than 0");

        players[msg.sender] = Player(msg.sender, msg.value, betNumber);
        playerState[msg.sender] = PlayerState.PLAYING;

        emit BetPlaced(msg.sender, msg.value, betNumber);
    }

    // Reveal the bet
    function revealBet() public {
        require(
            gameState == GameState.BETTING_OPEN,
            "Betting is not open at the moment"
        );
        require(
            playerState[msg.sender] == PlayerState.PLAYING,
            "You are not playing"
        );

        Player memory player = players[msg.sender];

        if (crashNumber <= player.betNumber) {
            // Bet won
            uint256 winnings = (player.betAmount * 100) / player.betNumber;
            payable(msg.sender).transfer(winnings);

            emit BetWon(
                msg.sender,
                player.betAmount,
                player.betNumber,
                crashNumber
            );
        } else {
            // Bet lost
            emit BetLost(
                msg.sender,
                player.betAmount,
                player.betNumber,
                crashNumber
            );
        }

        playerState[msg.sender] = PlayerState.NOT_PLAYING;
    }

    // Withdraw funds
    function withdraw() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    // Fallback function
    fallback() external payable {}

    receive() external payable {
        revert();
    }
}
