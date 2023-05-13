import { ethers } from 'hardhat';

async function main() {
  const curBlackjack = '0xbe4D23E63DDc10369BDecfc6a95B89bCa2E2D065';
  // Get blackjack at that address
  const Blackjack = await ethers.getContractAt('Blackjack', curBlackjack);

  const testData = await Blackjack.playerCards(
    '0x935CC8Efc9E96C5538f7a376342BA633022079A5'
  );

  console.log(testData);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
