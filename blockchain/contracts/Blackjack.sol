// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "./Constants.sol";
import "./utils/BreakdownUint256.sol";

contract Blackjack is VRFConsumerBaseV2, Ownable, BreakdownUint256 {
    // Self destruct
    bool public isSelfDestruct = false;

    // VRF parameters
    VRFCoordinatorV2Interface COORDINATOR;
    LinkTokenInterface LINKTOKEN;
    uint64 public subscriptionId;
    uint256 public requestId;
    uint256[] public randomWords;

    event HandStarted(address indexed player, uint256 bet);
    event PlayerWin(
        address indexed player,
        uint256 bet,
        uint256 payout,
        Card[] playerCards,
        Card[] dealerCards
    );
    event DealerWin(
        address indexed player,
        uint256 bet,
        uint256 payout,
        Card[] playerCards,
        Card[] dealerCards
    );
    event Tie(
        address indexed player,
        uint256 bet,
        uint256 payout,
        Card[] playerCards,
        Card[] dealerCards
    );

    event HandInitialized(address indexed player);
    event PlayerHit(address indexed player);
    event PlayerStand(address indexed player);
    event DealerVRFRequested(address indexed player);
    event PlayerVRFReceived(address indexed player);
    event DealerVRFReceived(address indexed player);

    enum State {
        INACTIVE,
        WAITING_FOR_INIT_VRF,
        PLAYER_TURN,
        WAITING_FOR_PLAYER_VRF,
        WAITING_FOR_DEALER_VRF
    }

    enum Card {
        ACE,
        TWO,
        THREE,
        FOUR,
        FIVE,
        SIX,
        SEVEN,
        EIGHT,
        NINE,
        TEN,
        JACK,
        QUEEN,
        KING
    }

    struct GameState {
        Card[] playerCards;
        Card[] dealerCards;
        uint256 bet;
        State blackjackstate;
        address playerAddress;
    }

    function dealerCards(address player) public view returns (Card[] memory) {
        return gamesStates[player].dealerCards;
    }

    function playerCards(address player) public view returns (Card[] memory) {
        return gamesStates[player].playerCards;
    }

    function VRFCards(address player) public view returns (uint8[] memory) {
        return vrfRequests[addressToVRF[player]].cards;
    }

    mapping(address => GameState) public gamesStates;
    mapping(address => uint256) public addressToVRF;
    // key value is requestIndex given by VRF Coordinator
    mapping(uint256 => VRFRequest) public vrfRequests;
    mapping(uint8 => uint8) public cardValues;

    enum VRFRequestType {
        INIT,
        PLAYER,
        DEALER
    }

    struct VRFRequest {
        VRFRequestType vrfRequestType;
        address playerAddress;
        bool isFulfilled;
        uint timestamp;
        uint8[] cards;
    }

    constructor(
        address vrfCoordinator,
        address link
    ) payable VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        subscriptionId = COORDINATOR.createSubscription();
        COORDINATOR.addConsumer(subscriptionId, address(this));
        LINKTOKEN = LinkTokenInterface(link);
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
        addressToVRF[msg.sender] = requestId_;
    }

    function requestRandomWords() public returns (uint256) {
        uint256 requestId_ = COORDINATOR.requestRandomWords(
            0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f,
            subscriptionId,
            3,
            2_500_000,
            1
        );
        addressToVRF[msg.sender] = requestId_;
        return requestId_;
    }

    function calculateHandValue(
        Card[] memory cards
    ) public pure returns (uint8) {
        uint8 handValue = 0;
        uint8 aces = 0;

        for (uint8 i = 0; i < cards.length; i++) {
            uint8 card = uint8(cards[i]);

            if (card == 0) {
                handValue += 11;
                aces++;
            } else if (card > 0 && card < 10) {
                handValue += card + 1;
            } else {
                handValue += 10;
            }
        }

        while (handValue > 21 && aces > 0) {
            handValue -= 10;
            aces--;
        }

        return handValue;
    }

    function viewPlayerTotal(address player) public view returns (uint8) {
        return calculateHandValue(gamesStates[player].playerCards);
    }

    function viewDealerTotal(address player) public view returns (uint8) {
        return calculateHandValue(gamesStates[player].dealerCards);
    }

    function uint8ToCard(uint8 randomUint8) public pure returns (Card) {
        // If uint8 is above 247, it will be rehashed
        // to a number between 0 and 247
        while (randomUint8 > 247) {
            bytes32 hashedInput = keccak256(abi.encodePacked(randomUint8));
            randomUint8 = uint8(uint256(hashedInput) % 256);
        }

        uint8 card = randomUint8 % 13;
        require(card <= uint8(Card.KING), "Invalid card value");
        return Card(card);
    }

    function showGameState() external view returns (GameState memory) {
        return gamesStates[msg.sender];
    }

    function fulfillRandomWords(
        uint256 requestId_,
        uint256[] memory randomWords_
    ) internal override {
        randomWords = randomWords_;

        VRFRequest storage vrfRequest = vrfRequests[requestId_];
        vrfRequest.isFulfilled = true;

        // require(!vrfRequest.isFulfilled, "Request is already fulfilled");

        uint256 randomWord = randomWords[0];

        uint8[] memory randomUint8s = getUint256BrokenIntoUint8(randomWord);

        vrfRequest.cards = [
            randomUint8s[0],
            randomUint8s[1],
            randomUint8s[2],
            randomUint8s[3],
            randomUint8s[4],
            randomUint8s[5]
        ];

        if (vrfRequest.vrfRequestType == VRFRequestType.INIT) {
            fulfillInit(requestId_);
        } else if (vrfRequest.vrfRequestType == VRFRequestType.PLAYER) {
            fulfillPlayerTurn(requestId_);
        } else if (vrfRequest.vrfRequestType == VRFRequestType.DEALER) {
            fulfillDealerTurn(requestId_);
        }
    }

    function fulfillInit(uint256 requestId_) private {
        VRFRequest storage vrfRequest = vrfRequests[requestId_];

        address player = vrfRequest.playerAddress;

        GameState storage gameState = gamesStates[player];

        require(
            gameState.blackjackstate == State.WAITING_FOR_INIT_VRF,
            "Game is not waiting for init VRF"
        );

        Card playerCard1 = uint8ToCard(vrfRequest.cards[0]);
        Card playerCard2 = uint8ToCard(vrfRequest.cards[1]);
        Card dealerCard1 = uint8ToCard(vrfRequest.cards[2]);

        gameState.playerCards.push(playerCard1);
        gameState.playerCards.push(playerCard2);
        gameState.dealerCards.push(dealerCard1);

        gameState.blackjackstate = State.PLAYER_TURN;

        emit HandInitialized(player);
    }

    function fulfillPlayerTurn(uint256 requestId_) private {
        VRFRequest storage vrfRequest = vrfRequests[requestId_];

        address player = vrfRequest.playerAddress;

        GameState storage gameState = gamesStates[player];

        require(
            gameState.blackjackstate == State.WAITING_FOR_PLAYER_VRF,
            "Game is not waiting for player VRF"
        );

        uint8[] memory randomUint8s = vrfRequest.cards;

        Card playerCard = uint8ToCard(randomUint8s[0]);

        addPlayerCard(gameState, playerCard);
        emit PlayerVRFReceived(player);
    }

    function fulfillDealerTurn(uint256 requestId_) private {
        emit DealerVRFReceived(msg.sender);
        VRFRequest storage vrfRequest = vrfRequests[requestId_];

        address player = vrfRequest.playerAddress;

        GameState storage gameState = gamesStates[player];

        require(
            gameState.blackjackstate == State.WAITING_FOR_DEALER_VRF,
            "Game is not waiting for dealer VRF"
        );

        uint8[] memory randomUint8s = vrfRequest.cards;

        for (uint256 i = 0; i < 5; i++) {
            Card dealerCard = uint8ToCard(randomUint8s[i]);
            if (addDealerCard(gameState, dealerCard)) {
                // Dealer has 17 or more
                break;
            }
        }

        // find winner
        uint8 playerValue = calculateHandValue(gameState.playerCards);
        uint8 dealerValue = calculateHandValue(gameState.dealerCards);

        if (dealerValue > 21) {
            // player won
            payable(player).transfer(gameState.bet * 2);
            gameState.blackjackstate = State.INACTIVE;
            emit PlayerWin(
                player,
                gameState.bet,
                gameState.bet * 2,
                gameState.playerCards,
                gameState.dealerCards
            );
        } else if (playerValue > dealerValue) {
            // player won
            payable(player).transfer(gameState.bet * 2);
            gameState.blackjackstate = State.INACTIVE;
            emit PlayerWin(
                player,
                gameState.bet,
                gameState.bet * 2,
                gameState.playerCards,
                gameState.dealerCards
            );
        } else if (playerValue == dealerValue) {
            // tie
            payable(player).transfer(gameState.bet);
            gameState.blackjackstate = State.INACTIVE;
            emit Tie(
                player,
                gameState.bet,
                gameState.bet,
                gameState.playerCards,
                gameState.dealerCards
            );
        } else if (playerValue < dealerValue) {
            // player lost
            gameState.blackjackstate = State.INACTIVE;
            emit DealerWin(
                player,
                gameState.bet,
                0,
                gameState.playerCards,
                gameState.dealerCards
            );
        }
    }

    function addPlayerCard(GameState storage gameState, Card card) private {
        gameState.playerCards.push(card);
        uint8 value = calculateHandValue(gameState.playerCards);
        if (value > 21) {
            gameState.blackjackstate = State.INACTIVE;
            emit DealerWin(
                gameState.playerAddress,
                gameState.bet,
                0,
                gameState.playerCards,
                gameState.dealerCards
            );
        } else {
            gameState.blackjackstate = State.PLAYER_TURN;
        }
    }

    function addDealerCard(
        GameState storage gameState,
        Card card
    ) private returns (bool) {
        gameState.dealerCards.push(card);
        uint8 value = calculateHandValue(gameState.dealerCards);
        if (value > 16) {
            gameState.blackjackstate = State.INACTIVE;
            return true;
        } else {
            gameState.blackjackstate = State.INACTIVE;
            return false;
        }
    }

    function deal() public payable {
        require(!isSelfDestruct, "Contract has been self destructed.");

        address player = msg.sender;
        GameState storage gameState = gamesStates[player];

        require(
            gameState.blackjackstate == State.INACTIVE,
            "Game is already in progress"
        );

        // Bet amount must be less than 1 ether
        require(msg.value < 1 ether, "Bet amount must be less than 1 ether");

        // Bet amount must be greater than 0.01 ether
        require(
            msg.value > 0.0001 ether,
            "Bet amount must be greater than 0.0001 ether"
        );

        // Memory error, doing it manually for now
        // gameState = GameState({
        //     bet: msg.value,
        //     blackjackstate: State.WAITING_FOR_INIT_VRF,
        //     playerCards: new Card[](0),
        //     dealerCards: new Card[](0),
        //     playerAddress: player
        // });

        gameState.bet = msg.value;
        gameState.blackjackstate = State.WAITING_FOR_INIT_VRF;
        gameState.playerCards = new Card[](0);
        gameState.dealerCards = new Card[](0);
        gameState.playerAddress = player;

        requestInitVRF();
        emit HandStarted(player, msg.value);
    }

    function hit() public {
        address player = msg.sender;
        GameState storage gameState = gamesStates[player];

        require(
            gameState.blackjackstate == State.PLAYER_TURN,
            "Game is not in player turn"
        );

        gameState.blackjackstate = State.WAITING_FOR_PLAYER_VRF;
        requestPlayerVRF(player);
        emit PlayerHit(player);
    }

    function stand() public {
        address player = msg.sender;
        GameState storage gameState = gamesStates[player];

        require(
            gameState.blackjackstate == State.PLAYER_TURN,
            "Game is not in player turn"
        );

        gameState.blackjackstate = State.WAITING_FOR_DEALER_VRF;
        requestDealerVRF(player);
        emit PlayerStand(player);
    }

    function requestInitVRF() private {
        VRFRequest memory vrfRequest = VRFRequest(
            VRFRequestType.INIT,
            msg.sender,
            false,
            block.timestamp,
            new uint8[](0)
        );

        uint256 requestId_ = requestRandomWords();

        vrfRequests[requestId_] = vrfRequest;
    }

    function requestPlayerVRF(address player) private {
        VRFRequest memory vrfRequest = VRFRequest(
            VRFRequestType.PLAYER,
            player,
            false,
            block.timestamp,
            new uint8[](0)
        );

        uint256 requestId_ = requestRandomWords();

        vrfRequests[requestId_] = vrfRequest;
    }

    function requestDealerVRF(address player) private {
        VRFRequest memory vrfRequest = VRFRequest(
            VRFRequestType.DEALER,
            player,
            false,
            block.timestamp,
            new uint8[](0)
        );

        uint256 requestId_ = requestRandomWords();

        vrfRequests[requestId_] = vrfRequest;

        emit DealerVRFRequested(player);
    }

    function withdraw(address payable to, uint256 amount) public onlyOwner {
        to.transfer(amount);
    }

    function selfDestruct() public onlyOwner {
        // Self destruct is being deleted in an upcoming hard fork
        // selfdestruct(payable(owner()));
        // Instead, lets send all the money to the owner
        // and then lock the contract.
        withdraw(payable(owner()), address(this).balance);
        isSelfDestruct = true;
    }
}
