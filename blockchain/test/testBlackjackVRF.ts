import { expect } from 'chai';
import hre from 'hardhat';
import { time } from '@nomicfoundation/hardhat-network-helpers';
import crypto from 'crypto';
import abi from '@chainlink/contracts/abi/v0.8/LinkTokenInterface.json';

const VERIFY = true;

// Test only this file with npx hardhat --network mumbai test test/testBlackjackVRF.ts

// Add/remove .skip when testing. Must test on a real chain to get response.
// describe('Random Number Processing', function () {
describe('Blackjack VRF', function () {
  it('Should create a VRF subscription', async function () {
    // 5 gwei gas price for faster transactions
    const gasPrice = hre.ethers.utils.parseUnits('10', 'gwei');

    const mumbaiCoordinator = '0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed';
    const mumbaiLink = '0x326C977E6efc84E512bB9C30f76E30c160eD06FB';
    const [owner] = await hre.ethers.getSigners();
    const linkToken = await hre.ethers.getContractAt(abi, mumbaiLink);

    const Blackjack = await hre.ethers.getContractFactory('Blackjack');
    const blackjackMock = await Blackjack.deploy(
      mumbaiCoordinator,
      mumbaiLink,
      { gasPrice: gasPrice, value: hre.ethers.utils.parseEther('0.001') }
    );
    // await 5 blocks for etherscan
    await blackjackMock.deployed();

    if (VERIFY) {
      await blackjackMock.deployTransaction.wait(7);
      // verify contract on polygonscan, try in case it already is verified
      // try catch block
      try {
        await hre.run('verify:verify', {
          address: blackjackMock.address,
          contract: `contracts/Blackjack.sol:Blackjack`,
          constructorArguments: [mumbaiCoordinator, mumbaiLink],
        });
      } catch (error) {
        console.log(error);
      }
    }
    // Get the VRF subscription
    const subscription = await blackjackMock.subscriptionId();
    console.log(subscription);
    // // Send it 0.1 Link from owner

    const linkAmount = hre.ethers.utils.parseEther('0.3');
    const txn = await linkToken.transfer(blackjackMock.address, linkAmount);
    await txn.wait();
    console.log('Link sent to contract.');

    // // Fund the VRF subscription
    const fundTxn = await blackjackMock.fund(linkAmount, {
      gasPrice: gasPrice,
    });
    await fundTxn.wait();

    console.log('Link funded.');

    // // Request a random number
    const dealTxn = await blackjackMock.deal({
      value: hre.ethers.utils.parseEther('0.00011'),
      gasPrice: gasPrice,
    });

    console.log('Dealt');
    await dealTxn.wait(10);

    // Hit
    const hitTxn = await blackjackMock.hit();
    console.log('Hit');

    await hitTxn.wait(10);

    // Stand
    const standTxn = await blackjackMock.stand();
    console.log('Stand');

    await standTxn.wait(10);

    // Get blackjack balance
    const balance = await hre.ethers.provider.getBalance(blackjackMock.address);
    // Get owner address
    const ownerAddress = await owner.getAddress();

    // Withdraw balance
    const withdrawTxn = await blackjackMock.withdraw(ownerAddress, balance, {
      gasPrice: gasPrice,
    });

    expect(true);
  });
});
