require("@nomiclabs/hardhat-waffle");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.4",
        settings: {
          optimizer: {
            enabled: true,
            runs: 6666
          }
        }
      }
    ],
    overrides: {
      "contracts/TetherToken.sol": {
        version: "0.4.18"
      }
    }

  },
  defaultNetwork: "hardhat", // hardhat localhost
  networks: {
    localhost: {
      url: "http://127.0.0.1:40000",
      chainId: 1024,
      gasPrice: 5000000000,
      accounts: ["f78a036930ce63791ea6ea20072986d8c3f16a6811f6a2583b0787c45086f769", "95e06fa1a8411d7f6693f486f0f450b122c58feadbcee43fbd02e13da59395d5"],
    }
  },
};
