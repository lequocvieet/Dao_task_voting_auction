const hre = require("hardhat");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

async function main() {
  //Setup account
  var [account0, account1, account2, account3, account4] =
    await ethers.getSigners();

  console.log("contract owner", account0.address);
  console.log("account1", account1.address);
  console.log("account2", account2.address);
  console.log("account1", account3.address);
  console.log("account2", account4.address);

  const hardhat_node_provider = new ethers.providers.JsonRpcProvider(
    "http://127.0.0.1:8545/"
  );
  const goerli_node_provider = new ethers.providers.JsonRpcProvider(
    "https://goerli.infura.io/v3/2e5775eb41aa490991bff9eb183e1122"
  );

  //Deploy TaskManager
  TaskManager = await hre.ethers.getContractFactory("TaskManager");
  taskManager = await TaskManager.deploy();
  await taskManager.deployed();
  console.log("TaskManager deploy at:", taskManager.address);

  //Deploy BatchTaskVoting
  BatchTaskVoting = await hre.ethers.getContractFactory("BatchTaskVoting");
  batchTaskVoting = await BatchTaskVoting.deploy();
  await batchTaskVoting.deployed();
  console.log("BatchTaskVoting deploy at:", batchTaskVoting.address);

  //Deploy TaskAuction
  TaskAuction = await hre.ethers.getContractFactory("TaskAuction");
  taskAuction = await TaskAuction.deploy();
  await batchTaskVoting.deployed();
  console.log("TaskAuction deploy at:", taskAuction.address);

  //Deploy CreditScore
  CreditScore = await hre.ethers.getContractFactory("CreditScore");
  creditScore = await CreditScore.deploy();
  await creditScore.deployed();
  console.log("CreditScore deploy at:", creditScore.address);

  //BankManager vs Token used for later version

  //------------------------------------------Test Logic--------------------------------------

  //TaskManager set BatchTaskVoting
  await taskManager.setBatchTaskVoting(batchTaskVoting.address);

  //TaskManager set TaskAuction
  await taskManager.setTaskAuction(taskAuction.address);

  //TaskManager set CreditScore
  await taskManager.setCreditScore(creditScore.address);

  //TaskAuction setTaskManager
  await taskAuction.setTaskManager(taskManager.address);

  //BatchTaskVoting set TaskManager
  await batchTaskVoting.setTaskManager(taskManager.address);

  //TaskManager initPoll, init BatchTask and init Task
  //choose account1 to be pollOwner
  //await taskManager.initPoll();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
