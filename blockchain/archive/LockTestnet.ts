import { ethers } from 'hardhat';
import { expect } from 'chai';

describe('Lock', function () {
  let lock: any;

  before(async function () {
    const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
    const currentTime = Math.floor(Date.now() / 1000);
    const unlockTime = currentTime + ONE_YEAR_IN_SECS;

    const Lock = await ethers.getContractFactory('Lock');
    lock = await Lock.deploy(unlockTime, { value: 1 });

    const [owner] = await ethers.getSigners();

    const ownerBalance = await ethers.provider.getBalance(owner.address);
    console.log('Owner balance: ', ownerBalance.toString());
  });

  it('Should set the correct owner', async function () {
    const [owner] = await ethers.getSigners();
    // Get owner balance

    expect(await lock.owner()).to.equal(owner.address);
  });
});
