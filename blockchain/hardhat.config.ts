import '@nomicfoundation/hardhat-toolbox';
import { HardhatUserConfig } from 'hardhat/config';
import 'hardhat-deploy';

// import and init dotenv
import dotenv from 'dotenv';
dotenv.config();

// Check private key
if (process.env.PRIVATE_KEY) {
  console.log('Warning: PRIVATE_KEY is set. Be cautious.');
}

// Check forking config
if (process.env.FORKING_ENABLED === 'true') {
  if (!process.env.FORKING_NETWORK) {
    throw new Error('FORKING_URL must be set when FORKING_ENABLED is true');
  }
}
// Check network config
enum ForkingNetwork {
  Mainnet = 'mainnet',
  Mumbai = 'mumbai',
  Sepolia = 'sepolia',
  Polygon = 'polygon',
}

if (process.env.FORKING_ENABLED === 'true') {
  console.log('Forking enabled', process.env.FORKING_NETWORK);
}

let FORKING_NETWORK_URL = '';
if (process.env.FORKING_NETWORK) {
  if (
    !Object.values(ForkingNetwork).includes(
      process.env.FORKING_NETWORK as ForkingNetwork
    )
  ) {
    throw new Error(
      `FORKING_NETWORK must be one of ${Object.values(ForkingNetwork).join(
        ', '
      )}`
    );
  }
  FORKING_NETWORK_URL =
    process.env[`INFURA_${process.env.FORKING_NETWORK.toUpperCase()}`] || '';
}

const FORKING_ENABLED = process.env.FORKING_ENABLED === 'true';
const FORKING_NETWORK = process.env.FORKING_NETWORK as ForkingNetwork;
const PRIVATE_KEY = process.env.PRIVATE_KEY || '';
const INFURA_MAINNET = process.env.INFURA_MAINNET || '';
const INFURA_MUMBAI = process.env.INFURA_MUMBAI || '';
const INFURA_POLYGON = process.env.INFURA_POLYGON || '';
const INFURA_SEPOLIA = process.env.INFURA_SEPOLIA || '';
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || '';
const POLYGONSCAN_API_KEY = process.env.POLYGONSCAN_API_KEY || '';

const config: HardhatUserConfig = {
  networks: {
    hardhat: {
      forking: {
        enabled: FORKING_ENABLED,
        url: FORKING_NETWORK_URL,
        blockNumber: 34861450,
      },
      accounts: PRIVATE_KEY
        ? [
            {
              privateKey: PRIVATE_KEY,
              balance: '10000000000000000000',
            },
          ]
        : undefined,
    },
    mainnet: {
      url: INFURA_MAINNET,
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : undefined,
    },
    mumbai: {
      url: INFURA_MUMBAI,
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : undefined,
    },
    polygon: {
      url: INFURA_POLYGON,
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : undefined,
    },
    sepolia: {
      url: INFURA_SEPOLIA,
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : undefined,
    },
  },

  solidity: '0.8.18',
  etherscan: {
    apiKey: {
      sepolia: ETHERSCAN_API_KEY,
      polygonMumbai: POLYGONSCAN_API_KEY,
      mainnet: ETHERSCAN_API_KEY,
      polygon: POLYGONSCAN_API_KEY,
    },
  },
  mocha: {
    timeout: 100000000,
  },
};

export default config;
