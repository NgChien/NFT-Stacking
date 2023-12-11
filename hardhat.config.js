require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-verify");
/** @type import('hardhat/config').HardhatUserConfig */
require("dotenv").config();
module.exports = {
  solidity: "0.8.0",
  settings: {
    optimizer: {
      enabled: true,
      runs: 1000,
    },
  },

  paths: {
    artifacts: "../sim_front_end/src/abis/build", // Đường dẫn đến thư mục muốn lưu trữ tệp .json
  },

  networks: {
    bsctest: {
      url: `https://data-seed-prebsc-1-s1.binance.org:8545/`,
      accounts: [process.env.PRIV_KEY],
    },
  },
  etherscan: {
    apiKey: {
      bscTestnet: process.env.API_KEY,
    },
  },
};
