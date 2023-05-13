import { expect } from 'chai';
import hre from 'hardhat';
import { time } from '@nomicfoundation/hardhat-network-helpers';
import crypto from 'crypto';
import abi from '@chainlink/contracts/abi/v0.8/LinkTokenInterface.json';

const VERIFY = true;

// Test only this file with npx hardhat --network mumbai test test/testVRFMumbai.ts

// Add/remove .skip when testing. Must test on a real chain to get response.
// describe('Random Number Processing', function () {
describe.skip('Random Number Processing', function () {
  it('Should create a VRF subscription', async function () {
    const mumbaiCoordinator = '0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed';
    const mumbaiLink = '0x326C977E6efc84E512bB9C30f76E30c160eD06FB';
    const [owner] = await hre.ethers.getSigners();
    const linkToken = await hre.ethers.getContractAt(abi, mumbaiLink);

    const VRFMock = await hre.ethers.getContractFactory('TestVRF');
    const vrfMock = await VRFMock.deploy(mumbaiCoordinator, mumbaiLink);
    // await 5 blocks for etherscan
    await vrfMock.deployed();

    if (VERIFY) {
      await vrfMock.deployTransaction.wait(7);
      // verify contract on polygonscan, try in case it already is verified
      // try catch block
      try {
        await hre.run('verify:verify', {
          address: vrfMock.address,
          contract: `contracts/testVRF/TestVRF.sol:TestVRF`,
          constructorArguments: [mumbaiCoordinator, mumbaiLink],
        });
      } catch (error) {
        console.log(error);
      }
    }
    // Get the VRF subscription
    const subscription = await vrfMock.subscriptionId();
    console.log(subscription);
    // Send it 0.1 Link from owner
    const linkAmount = hre.ethers.utils.parseEther('0.3');
    const txn = await linkToken.transfer(vrfMock.address, linkAmount);
    await txn.wait();

    // Fund the VRF subscription
    const fundTxn = await vrfMock.fund(linkAmount);
    await fundTxn.wait();

    // Request a random number
    const randomRequestTxn = await vrfMock.randomnessIsRequestedHere();
    await randomRequestTxn.wait();
    // console.log(randomNumber);

    expect(true);
  });
});
