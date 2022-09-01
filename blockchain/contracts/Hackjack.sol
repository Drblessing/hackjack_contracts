// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

// Debugging
import "hardhat/console.sol";

// NFTs and Counter
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

// VRF
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

// Utils
import "./Destructible.sol";
import "./BreakdownUint256.sol";

// TODO: Add 2 hr time list where you can redeem bet if no VRF https://github.com/sakuracasino/roulette-contract/blob/master/contracts/Roulette.sol
// TODO: Data structure to track whether requests have been filled or not


// Unstoppable Blackjack on the Blockchain!
contract Hackjack is VRFConsumerBaseV2, Destructible, BreakdownUint256 {
    // Attach Counters Library functions to Coutners.Counter struct
    using Counters for Counters.Counter;

    // VRF
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

    // NFT
    // Counter for NFTs
    Counters.Counter private _tokenIds;
    uint256 trophyVersion;
    uint256 newItemId;

    // Temp: Random salt until Chainlink VRF
    uint256 public salt = 314159265;

    // DAO
    uint256 nProposals;
    mapping(address => bool) public voter;
    mapping(uint => Proposal) public proposals;
    event Voted(address sender, uint transactionId);
    event Submission(uint transactionId);
    struct Proposal {
        address payable recipient;
        uint value;
        uint nVotes;
        uint sessionId;
        bool executed;
    }

    // Blackjack
    // Counter for Blackjack hands
    Counters.Counter private _handCounter;
    // 0.001 < bet < 0.1 Ethereum
    // Have to balance the ratio of (total contract amount / maxBet) to avoid
    // the contract going bust
    uint256 public minBet = 0.001 ether;
    uint256 public maxBet = 10 ether;
    // Temp: Users can only play one hand of Blackjack at at time
    mapping(address => bool) public isPlaying;
    // Player to handId
    mapping(address => uint256) public playerHand;
    // handId to player
    mapping(uint256 => address) public handOwner;
    // Card to card value, (0-12) => (2-11)
    // (0 = Ace) => 11
    // (1 = 2) => 2
    // ...
    // (12 = King) => 10
    mapping(uint8 => uint8) public cardValues;

    event NewGame(
        uint256 handId,
        address player,
        uint256 bet,
        uint8 firstCard,
        uint8 secondCard,
        uint8 dealerCard
    );
    event PlayerHit(uint256 handId, address player, uint8 card);
    event DealerHit(uint256 handId, uint8 card);
    event Busted(uint256 handId, address player, uint256 value_lost);
    event Winner(uint256 handId, address player, uint256 value_won);
    event Tie(uint256 handId, address player, uint256 value_tie);
    event HandOver(uint256 handId);

    struct Hand {
        uint8[] playerCards;
        uint8[] dealerCards;
        uint8 playerTotal;
        uint8 dealerTotal;
        uint256 bet;
        bool isWon;
        bool isBusted;
        bool isTied;
    }
    Hand[] public hands;

    /// Players can only play active hands.
    modifier onlyPlayable(uint256 _handId) {
        require(
            hands[_handId].isBusted == false,
            "Error: Your hand is busted."
        );
        require(hands[_handId].isWon == false, "Error: Your hand is won!");
        require(hands[_handId].isTied == false, "Erorr: Your hand is tied.");
        _;
    }

    /// Players can only play their own hand.
    modifier onlyHandOwner(uint256 _handId) {
        require(
            handOwner[_handId] == msg.sender,
            "Error: You are not the owner."
        );
        _;
    }

    /// Players can only bet within predefined limits.
    modifier onlyBetWithinLimits() {
        uint betAmount = msg.value * 11;
        uint contractAmount = address(this).balance;

        require(
            msg.value >= minBet && msg.value <= maxBet,
            "Error: You have bet oustide the bet limits. Please bet within the minBet and maxBet."
        );
        require(
            contractAmount > betAmount,
            "Error: You must bet less than 11 times the contracts balance."
        );
        _;
    }

    /// Players can only play one hand at a time.
    modifier onlyOneHand() {
        require(!isPlaying[msg.sender]);
        _;
    }

    constructor()
        payable
        VRFConsumerBaseV2(vrfCoordinator)
    {
        // VRF
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_owner = msg.sender;
        subscriptionId = 1327;

        // Init cardValues mapping
        cardValues[0] = 11; // A
        cardValues[1] = 2; // 2
        cardValues[2] = 3; // 3
        cardValues[3] = 4; // ...
        cardValues[4] = 5;
        cardValues[5] = 6;
        cardValues[6] = 7;
        cardValues[7] = 8;
        cardValues[8] = 9;
        cardValues[9] = 10; // 10
        cardValues[10] = 10; // J
        cardValues[11] = 10; // Q
        cardValues[12] = 10; // K
        // Increment _handCounter to avoid bugs with mapping
        // since mapping starts with 0
        _handCounter.increment();
        // Add dummy hand 0
        Hand memory hand = Hand(
            new uint8[](0),
            new uint8[](0),
            0,
            0,
            msg.value,
            false,
            false,
            false
        );

        hands.push(hand);
    }

    /// Check Hand Counter
    function viewHandCounter() public view returns (uint HandCounterValue) {
        HandCounterValue = _handCounter.current();
    }

    /// Deal a new hand of Blacjack!
    function deal() public payable onlyBetWithinLimits onlyOneHand {
        isPlaying[msg.sender] = true;

        // Record which hand the player is playing and vice versa
        uint _handId = _handCounter.current();
        playerHand[msg.sender] = _handId;
        handOwner[_handCounter.current()] = msg.sender;
        console.log("New Game:", _handCounter.current(), msg.sender);

        // Add hand to hands
        Hand memory hand = Hand(
            new uint8[](0),
            new uint8[](0),
            0,
            0,
            msg.value,
            false,
            false,
            false
        );
        hands.push(hand);

        // Deal first cards
        uint8 playerCard1 = dealPlayer(_handId);
        uint8 playerCard2 = dealPlayer(_handId);
        uint8 dealerCard = dealDealer(_handId);

        // Calculate and set player total
        setHandTotal(_handId, true);

        // Calcualte and set dealer total
        setHandTotal(_handId, false);

        // _mint(msg.sender, _handId); // create NFT representing ownership of hand

        emit NewGame(
            _handId,
            msg.sender,
            msg.value,
            playerCard1,
            playerCard2,
            dealerCard
        );

        // Increment hand counter
        _handCounter.increment();
    }

    /// View a hand.
    function check_hand(uint256 _handId) public view returns (Hand memory) {
        return hands[_handId];
    }

    /// Deal an arbitrary card
    function dealCard() private returns (uint8 card) {
        // Get random number and map it to cards
        card = uint8(getRandomNumber() % 13);
        console.log("Card dealt", card);
    }

    /// Deal a card to the player.
    function dealPlayer(uint256 _handId)
        private
        onlyHandOwner(_handId)
        onlyPlayable(_handId)
        returns (uint8 card)
    {
        card = dealCard();
        console.log("Deal Player with value", cardValues[card]);
        hands[_handId].playerCards.push(card);
        emit PlayerHit(_handId, msg.sender, card);
        return card;
    }

    /// Deal a card to the dealer.
    function dealDealer(uint256 _handId) private returns (uint8 card) {
        card = dealCard();
        console.log("Deal Dealer with value", cardValues[card]);
        hands[_handId].dealerCards.push(card);
        emit DealerHit(_handId, card);
        return card;
    }

    /// Calculate the total of a hand.
    function calculateHandTotal(uint8[] memory hand)
        public
        view
        returns (uint8 handTotal)
    {
        // TODO: Implement aces
        handTotal = 0;
        for (uint i = 0; i < hand.length; i++) {
            handTotal += cardValues[hand[i]];
        }
        console.log("Hand total", handTotal);
    }

    /// Calculate and set the total of a hand.
    function setHandTotal(uint256 _handId, bool player) private {
        if (player) {
            uint8 playerTotal = calculateHandTotal(hands[_handId].playerCards);
            hands[_handId].playerTotal = playerTotal;
        } else {
            uint8 dealerTotal = calculateHandTotal(hands[_handId].dealerCards);
            hands[_handId].dealerTotal = dealerTotal;
        }
    }

    /// Hit a player, set new total, and check for bust.
    function hit(uint256 _handId)
        public
        onlyPlayable(_handId)
        onlyHandOwner(_handId)
    {
        console.log("Player hits", _handId);
        dealPlayer(_handId);
        setHandTotal(_handId, true);
        checkPlayerBust(_handId);
    }

    /// Check if a player busts, resolve hand if they have.
    function checkPlayerBust(uint256 _handId)
        private
        onlyHandOwner(_handId)
        onlyPlayable(_handId)
    {
        if (hands[_handId].playerTotal > 21) {
            hands[_handId].isBusted = true;
            resolveHand(_handId);
        }
    }

    /// Player stands and hand is resolved
    function stand(uint256 _handId)
        public
        onlyPlayable(_handId)
        onlyHandOwner(_handId)
    {
        console.log("Player stands", _handId);
        resolveHand(_handId);
    }

    // Resolve dealer if hand is resolved and player did not bust
    function resolveDealer(uint256 _handId) private {
        // Dealers stands on 17
        if (hands[_handId].dealerTotal >= 17) {
            return;
        }

        // Dealer hits
        while (hands[_handId].dealerTotal < 17) {
            dealDealer(_handId);
            setHandTotal(_handId, false);
        }
    }

    /// Resolve a finished hand
    function resolveHand(uint256 _handId) private onlyHandOwner(_handId) {
        console.log("Hand Over: ", _handId);
        emit HandOver(_handId);
        // Player is done playing
        isPlaying[msg.sender] = false;
        // Player no longer owns this hand
        // nobody owns this hand
        handOwner[_handId] = 0x0000000000000000000000000000000000000000;
        // Player owns no hand
        playerHand[msg.sender] = 0;

        // Player loses hand
        // Nothing happens!
        if (hands[_handId].isBusted) {
            console.log("Player Busted on hand", _handId);
            emit Busted(_handId, msg.sender, hands[_handId].bet);
            // Better luck next time
            return;
        }

        // Resolve Dealer
        resolveDealer(_handId);
        // Check for player win
        if (
            hands[_handId].dealerTotal > 21 ||
            hands[_handId].playerTotal > hands[_handId].dealerTotal
        ) {
            // Congrats!
            hands[_handId].isWon = true;
            (bool sent, ) = address(payable(msg.sender)).call{
                value: hands[_handId].bet * 2
            }("");
            require(sent, "Failed to send Ether.");
            emit Winner(_handId, msg.sender, hands[_handId].bet);
            console.log("Player Wins!");
            return;
        }

        // Check for tie
        if (hands[_handId].dealerTotal == hands[_handId].playerTotal) {
            hands[_handId].isTied = true;
            (bool sent, ) = address(payable(msg.sender)).call{
                value: hands[_handId].bet
            }("");
            require(sent, "Failed to send Ether.");
            emit Tie(_handId, msg.sender, hands[_handId].bet);
            console.log("Tie.");
            return;
        }
        // Else player lost
        // DealerTotal > PlayerTotal && DealerTotal <= 21
        else {
            console.log("Player Lost. Better luck next time.");
            emit Busted(_handId, msg.sender, hands[_handId].bet);

            hands[_handId].isBusted = true;
        }
    }

    function getRandomNumber() private returns (uint256) {
        // TODO: Implement Chainlink
        uint256 blockNumber = block.number;
        salt++;
        return uint256(keccak256(abi.encodePacked(blockNumber + salt)));
    }

    // Increase casino bankroll if needed
    receive() external payable {}

    ////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////
    // VRF
    // Assumes the subscription is funded sufficiently.
    // Assumes the subscription is funded sufficiently.
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

    function pseudoFulfillRandomWords(uint256,uint256[] memory randomWords) external {
        s_randomWords = randomWords;
        fulfilledRandomUint8 = getUint256BrokenIntoUint8(s_randomWords[0]);
    }

    function breakRandomWords() public onlyOwner {
        fulfilledRandomUint8 = getUint256BrokenIntoUint8(s_randomWords[0]);
    }

    

}
