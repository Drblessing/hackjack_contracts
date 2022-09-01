import { time, loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { anyValue } from '@nomicfoundation/hardhat-chai-matchers/withArgs';
import { expect } from 'chai';
import { ethers } from 'hardhat';

describe('Hackjack', function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshopt in every test.
  async function deployHackjackFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();
    const provider = ethers.provider;
    const balance = await provider.getBalance(owner.address);
    console.log('My starting balance', ethers.utils.formatEther(balance));
    const Hackjack = await ethers.getContractFactory('Hackjack');
    const hackjack = await Hackjack.deploy({
      value: ethers.utils.parseEther('100'),
    });

    return { hackjack, owner, otherAccount };
  }

  describe('Deployment', function () {
    it('Should deploy with 100 ether', async function () {
      const { hackjack, owner } = await loadFixture(deployHackjackFixture);
      const contractAmount = parseInt(
        ethers.utils.formatEther(
          await hackjack.provider.getBalance(hackjack.address)
        )
      );
      expect(contractAmount).to.equal(100);
    });

    it('Should start with hand counter at 1', async function () {
      const { hackjack, owner } = await loadFixture(deployHackjackFixture);
      const counterIds = await hackjack.viewHandCounter();
      expect(counterIds).to.equal(1);
    });

    it('Should start a new game with .001 ether bet', async function () {
      const { hackjack, owner } = await loadFixture(deployHackjackFixture);
      const newGame = await hackjack.deal({
        value: ethers.utils.parseEther('.001'),
      });
      expect(true);
    });

    it('Should reject a too large bet of 10 ether', async function () {
      const { hackjack, owner } = await loadFixture(deployHackjackFixture);
      const test = await expect(
        hackjack.deal({
          value: ethers.utils.parseEther('11'),
        })
      ).to.be.reverted;
    });

    it('Should start a new game with 1 ether bet', async function () {
      const { hackjack, owner, otherAccount } = await loadFixture(
        deployHackjackFixture
      );
      const newGame = await hackjack.deal({
        value: ethers.utils.parseEther('1'),
      });

      expect(true);
    });

    it('Should increment counter on new game', async function () {
      const { hackjack, owner, otherAccount } = await loadFixture(
        deployHackjackFixture
      );
      const newGame = await hackjack.deal({
        value: ethers.utils.parseEther('1'),
      });
      const newGame2 = await hackjack.connect(otherAccount).deal({
        value: ethers.utils.parseEther('1'),
      });
      const counter = await hackjack.viewHandCounter();

      expect(counter).to.be.equal(3);
    });
  });

  describe('Get Random Numbers', function () {
    it('Should use gas', async function () {
      const { hackjack, owner } = await loadFixture(deployHackjackFixture);
      const functionGasFees =
        await hackjack.estimateGas.pseudoFulfillRandomWords(1, [
          ethers.BigNumber.from(
            '64437898801502570319900483953896592030659872321203918227738811002064266437203'
          ),
        ]);
      expect(true);
    });
  });

  describe('Destruction', function () {
    it('Should destroy itself', async function () {
      const { hackjack, owner } = await loadFixture(deployHackjackFixture);
      const destruction = await hackjack.destroy();
      const contractAmount = parseInt(
        ethers.utils.formatEther(
          await hackjack.provider.getBalance(hackjack.address)
        )
      );
      console.log('Contract amount', contractAmount);
      expect(contractAmount).to.equal(0);
      const provider = ethers.provider;
      const balance = await provider.getBalance(owner.address);
      console.log('MY balance', ethers.utils.formatEther(balance));
    });
  });
});
