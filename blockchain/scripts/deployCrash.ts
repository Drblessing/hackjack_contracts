import hre, { ethers } from 'hardhat';

async function main() {
  const Crash = await ethers.getContractFactory('Crash');
  const crash = await Crash.deploy();

  await crash.deployed();
  console.log('Crash deployed to:', crash.address);

  // Wait 10 seconds
  await new Promise((resolve) => setTimeout(resolve, 10000));

  // Verify
  await hre.run('verify:verify', {
    address: crash.address,
    constructorArguments: [],
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
