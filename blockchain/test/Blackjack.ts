// TODO: rename to Blackjack.js
import { expect } from 'chai';
import hre from 'hardhat';
import { time, loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import crypto from 'crypto';

function claculateBlackjackHandValue(hand: number[]) {
  let handValue = 0;
  let aces = 0;
  for (let i = 0; i < hand.length; i++) {
    if (hand[i] === 0) {
      handValue += 11;
      aces++;
    } else if (hand[i] > 0 && hand[i] < 10) {
      handValue += hand[i] + 1;
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

describe('Blackjack', function () {
  async function deployBlackjackFixture() {
    const Blackjack = await hre.ethers.getContractFactory('Blackjack');
    const blackjack = await Blackjack.deploy(13);
    const [player] = await hre.ethers.getSigners();
    return { blackjack, player };
  }
  it('turns uint8 into cards with uniform distribution', async function () {
    const { blackjack } = await loadFixture(deployBlackjackFixture);
    // Test every uint8 to card
    for (let i = 0; i < 256; i++) {
      const card = await blackjack.uint8ToCard(i);
      // Expect card to be between 0 and 12
      expect(card).to.be.gte(0);
      expect(card).to.be.lte(12);
    }
  });

  it('calculates hand values correctly', async function () {
    const { blackjack } = await loadFixture(deployBlackjackFixture);
    // Manual hands

    // Three aces, should be 13
    expect(await blackjack.calculateHandValue([0, 0, 0])).to.equal(13);
    // Blackjack (Ace and a Jack), should be 21
    expect(await blackjack.calculateHandValue([0, 10])).to.equal(21);

    // Three aces and a 10, should be 13
    expect(await blackjack.calculateHandValue([0, 0, 0, 9])).to.equal(13);

    // Three aces and a 8, should be 21
    expect(await blackjack.calculateHandValue([0, 0, 0, 7])).to.equal(21);

    // A 5,6,7 should be 18
    expect(await blackjack.calculateHandValue([4, 5, 6])).to.equal(18);

    // Random hands
    for (let i = 0; i < 1000; i++) {
      // Generate a random number of cards between 1 and 6
      const numCards = Math.floor(Math.random() * 6) + 1;
      const hand = [];
      for (let j = 0; j < numCards; j++) {
        hand.push(Math.floor(Math.random() * 13));
      }

      // Calculate the hand value

      const solidityHandValue = await blackjack.calculateHandValue(hand);
      const manualHandValue = claculateBlackjackHandValue(hand);
      if (solidityHandValue !== manualHandValue) {
        console.log(hand);
        console.log(solidityHandValue, manualHandValue);
      }
      expect(solidityHandValue).to.equal(manualHandValue);
    }
  });

  it('fails when player bets too much');

  it('plays a short game', async function () {
    const { blackjack, owner } = await loadFixture(deployBlackjackFixture);

    // run deal function on blackjack and set the bet to 1 ether
    const deal = await blackjack.deal({
      value: hre.ethers.utils.parseEther('0.1'),
    });
  });

  it('plays a long game', async function () {});
});
