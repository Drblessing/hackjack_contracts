import { ethers } from 'hardhat';

async function main() {
  // Print block
  const block = await ethers.provider.getBlock('latest');
  console.log('Block:', block.number);

  // Print account
  const [account] = await ethers.getSigners();
  console.log('Account:', account.address);
  const currentTimestampInSeconds = Math.round(Date.now() / 1000);
  const unlockTime = currentTimestampInSeconds + 60;

  const lockedAmount = ethers.utils.parseEther('0.00001');

  const Lock = await ethers.getContractFactory('Lock');
  const lock = await Lock.deploy(unlockTime, { value: lockedAmount });

  await lock.deployed();
  console.log(
    `Lock with ${ethers.utils.formatEther(
      lockedAmount
    )}ETH and unlock timestamp ${unlockTime} deployed to ${lock.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
