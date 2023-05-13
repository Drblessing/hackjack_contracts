import { expect } from 'chai';
import hre from 'hardhat';
import { time } from '@nomicfoundation/hardhat-network-helpers';
import crypto from 'crypto';
// TODO: rename to BreakdownUint256.js

function getRandomUint256() {
  // generate a random Uint8Array
  const array = new Uint8Array(32);
  crypto.getRandomValues(array);

  // convert the Uint8Array to a BigNumber
  const hex = '0x' + Buffer.from(array).toString('hex');
  const bigNumber = hre.ethers.BigNumber.from(hex);

  return bigNumber;
}

describe('Random Number Processing', function () {
  it('Should turn uint256 into uint8[](32)', async function () {
    const BreakDown = await hre.ethers.getContractFactory('BreakdownUint256');
    const breakdown = await BreakDown.deploy();

    // Test 10 times
    for (let i = 0; i < 10; i++) {
      const randomUint256 = getRandomUint256();

      // convert the BigNumber to a uint8 array using a bit mask starting from 0
      const uint8Array = randomUint256
        .toHexString()
        .slice(2)
        .padStart(64, '0')
        .match(/.{2}/g)!
        .map((byte) => parseInt(byte, 16));

      const breakdownResult = await breakdown.getUint256BrokenIntoUint8(
        randomUint256
      );

      // check for 32 uint8s
      expect(breakdownResult.length).to.equal(32);
      // Check the two arrays are the same
      expect(breakdownResult).to.deep.equal(uint8Array);
    }
  });
});
