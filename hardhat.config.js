require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.17",
      },
      {
        version: "0.5.16",
        settings: {},
      },
      {
        version: "0.8.9",
        settings: {},
      },

      {
        version: "0.6.6",
        settings: {},
      },
      {
        version: "0.5.10",
        settings: {},
      },
      {
        version: "0.4.0",
        settings: {},
      },
      {
        version: "0.4.23",
        settings: {},
      },
      {
        version: "0.6.12",
        settings: {},
      },
      {
        version: "0.5.12",
        settings: {},
      },
      {
        version: "0.8.0",
        settings: {},
      },
      {
        version: "0.6.4",
        settings: {},
      },
    ],
  },
  networks: {
    new: {
      url: "http://172.16.79.15:8545/",
    },
    hardhat: {
      allowUnlimitedContractSize: true,
    },
    sepolia: {
      url: "https://sepolia.infura.io/v3/2e5775eb41aa490991bff9eb183e1122",
      accounts: ["0x-private-key-here"],
    },
  },
};
