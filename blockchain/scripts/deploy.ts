import { ethers } from 'hardhat';
import hre from 'hardhat';
import { constructorArguments } from './arguments';

const deployContract = async (
  name: string,
  constructorArguments: any = null
) => {
  const contractName = name;
  const contractFactory = await ethers.getContractFactory(contractName);
  let contractInstance: any;
  if (constructorArguments) {
    const contractInstance = await contractFactory.deploy(
      constructorArguments,
      {}
    );
  } else {
    const contractInstance = await contractFactory.deploy({});
  }

  return contractInstance;
};

const main = async () => {
  const [owner, addr1, addr2] = await ethers.getSigners();
  const sub = await deployContract('VRFv2SubscriptionManagerTEST');
  const a = await deployContract('A', [sub.address]);
  console.log('Deployer Address', owner.address);
  console.log('Contract sub deployed to:', sub.address);
  console.log('Contract a deployed to:', a.address);

  await sub.addConsumer();
  await a.addConsumer();

  // await contractInstance.deployTransaction.wait(5);
  // await hre.run('verify:verify', {
  //   network: 'matic',
  //   contract: 'contracts/utils/SuperConsumer.sol:SuperConsumer',
  //   address: contractInstance.address,
  // });
};

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  console.log('ERROR DEPLOY');
  process.exitCode = 1;
});
