const hre = require("hardhat");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

async function main() {
  //Setup account
  var [account0, account1, account2, account3, account4, account5] =
    await ethers.getSigners();

  console.log("contract owner", account0.address);
  console.log("account1", account1.address);
  console.log("account2", account2.address);
  console.log("account3", account3.address);
  console.log("account4", account4.address);
  console.log("account5", account5.address);

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
  //choose account1 to be pollOwner account2 will be reporter,account3 will be reviewer of poll1
  await taskManager.initPoll(account1.address);
  //batchTask1 in poll1
  await taskManager.initBatchTask(1);
  //batchTask2 in poll1
  await taskManager.initBatchTask(1);

  //task1 in batchTask1
  await taskManager.initTask(
    1, //batchTaskId
    5, //point=4 hour*duration
    100, //reward
    20, //minReward
    account2.address, //reporter
    account3.address //reviewer
  );

  //task2 in batchTask1
  await taskManager.initTask(
    1, //batchTaskId
    15, //point=4 hour*duration
    100, //reward
    20, //minReward
    account2.address, //reporter
    account3.address //reviewer
  );

  //open poll for vote at task manager 1000s
  await taskManager.openPollForVote(1, 1000);

  //vote on batch task at batchTaskVoting
  //account4 vote on batchTask 1
  await batchTaskVoting.connect(account4).voteOnBatchTask(1, true); //1 is true

  //try to vote again and get revert
  //await batchTaskVoting.connect(account4).voteOnBatchTask(1, true);

  //call endvote at batchTaskVoting still soon
  //await batchTaskVoting.endVote();

  //Increase Time then call endVote again
  await time.increase(2000);
  await batchTaskVoting.endVote();

  //openBatchTaskForAuction at taskManager
  //open for batchTask1 with 1000s duration
  await taskManager.openBatchTaskForAuction(1, 1000);

  //user place bid on each task in TaskAuction
  //account 4 place bid 90wei on task1 of batchTask1 with current reward=100wei
  //account 5 place bid 80 wei on same task to kick account4 out
  await taskAuction.connect(account4).placeBid(1, { value: 90 });

  //Call end Auction at TaskAuction

  //User receiveTask at TaskManager

  //User submit TaskResult

  //Reviewer submit review Result

  //Todo: Some one want to extend their task

  //Check money payback sucessful
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
