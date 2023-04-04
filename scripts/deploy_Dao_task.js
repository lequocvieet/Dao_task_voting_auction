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

  //Deploy Token.sol
  Token = await hre.ethers.getContractFactory("Token");
  token = await Token.deploy("VNP", "VNP");
  await token.deployed();
  console.log("Token deploy at:", token.address);

  //Deploy BankManager.sol
  BankManager = await hre.ethers.getContractFactory("BankManager");
  bankManager = await BankManager.deploy();
  await bankManager.deployed();
  console.log("BankManager deploy at:", bankManager.address);

  //------------------------------------------INIT--------------------------------------

  //TaskManager set BatchTaskVoting
  await taskManager.setBatchTaskVoting(batchTaskVoting.address);

  //TaskManager set TaskAuction
  await taskManager.setTaskAuction(taskAuction.address);

  //TaskManager set BankManager
  await taskManager.setBankManager(bankManager.address);

  //Taskmanager set Token use
  await taskManager.chooseToken(token.address);

  //TaskManager set CreditScore
  await taskManager.setCreditScore(creditScore.address);

  //TaskAuction setTaskManager
  await taskAuction.setTaskManager(taskManager.address);

  //TaskAuction set BankManager
  await taskAuction.setBankManager(bankManager.address);

  //TaskAuction set Token use
  await taskAuction.chooseToken(token.address);

  //BatchTaskVoting set TaskManager
  await batchTaskVoting.setTaskManager(taskManager.address);

  let totalSupply = "1000";
  //BankManager mint token
  await bankManager.mint(
    token.address,
    bankManager.address,
    ethers.utils.parseEther(totalSupply)
  );

  //BankManager transfer Token for all account
  await bankManager.mint(
    token.address,
    account0.address,
    ethers.utils.parseEther("100")
  );
  await bankManager.mint(
    token.address,
    account1.address,
    ethers.utils.parseEther("100")
  );

  await bankManager.mint(
    token.address,
    account2.address,
    ethers.utils.parseEther("100")
  );

  await bankManager.mint(
    token.address,
    account3.address,
    ethers.utils.parseEther("100")
  );

  await bankManager.mint(
    token.address,
    account4.address,
    ethers.utils.parseEther("100")
  );

  await bankManager.mint(
    token.address,
    account5.address,
    ethers.utils.parseEther("100")
  );

  console.log(
    "Balance of Bank, account0, account1 ,account2,account3",
    await bankManager.balanceOf(bankManager.address, token.address),
    await bankManager.balanceOf(account0.address, token.address),
    await bankManager.balanceOf(account1.address, token.address),
    await bankManager.balanceOf(account2.address, token.address),
    await bankManager.balanceOf(account3.address, token.address),
    await bankManager.balanceOf(account4.address, token.address)
  );

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

  let polls = await taskManager.getAllPoll();
  console.log("polls", polls);

  let batchTasks = await taskManager.getAllBatchTaskByPollID(1);
  console.log("batchTasks", batchTasks);

  let tasks = await taskManager.getAllTask(1);
  console.log("tasks in batch1", tasks);

  //------------------------------------------Test Logic VOTING--------------------------------------

  //open poll for vote at task manager 1000s
  await taskManager.connect(account1).openPollForVote(1, 1000);

  //Filter OpenVote event
  filterOpenVote = taskManager.filters.OpenPollForVote(
    1,
    null,
    null,
    null,
    null
  );
  const resultsfilterOpenVote = await taskManager.queryFilter(filterOpenVote);
  console.log("resultsfilterOpenVote", resultsfilterOpenVote[0].args);

  //account4 vote on batchTask2
  await batchTaskVoting.connect(account4).voteOnBatchTask(2, 1);

  //vote again change to batchTask1
  await batchTaskVoting.connect(account4).voteOnBatchTask(1, 1);

  //account5 vote on batchTask1
  await batchTaskVoting.connect(account5).voteOnBatchTask(1, 1);

  //call endvote at batchTaskVoting too soon
  await batchTaskVoting.endVote();

  //Increase Time then call endVote again
  await time.increase(2000);
  await batchTaskVoting.endVote();

  //Filter EndVote event
  filter = batchTaskVoting.filters.EndVote(1, null, null, null);
  const results = await batchTaskVoting.queryFilter(filter);

  results.map((event) => {
    event = event.args;
    let batchTaskVoted = {
      pollId: event.pollId.toString(),
      pollState: event.pollState,
      batchTaskCanEnd: event.batchTaskCanEnd,
      endTime: event.endTime,
    };
    console.log("batchTaskVoted", batchTaskVoted);
  });

  filter1 = batchTaskVoting.filters.InitBatchTaskAuction(
    null,
    null,
    null,
    null
  );
  results1 = await batchTaskVoting.queryFilter(filter1);
  console.log("results1: ", results[0].args);

  // //------------------------------------------Test Logic AUCTION--------------------------------------

  //open for Auction batchTask1 with 1000s duration
  await taskManager.openBatchTaskForAuction(1, 1000);

  filter2 = taskAuction.filters.OpenTaskForAuction(1, null, null, null);
  results2 = await taskAuction.queryFilter(filter2);
  console.log("results2 ", results2[0].args);

  //account 4 place bid 90wei on task1 of batchTask1 with current reward=100wei
  //account 5 place bid 80 wei on same task to kick account4 out
  await taskAuction.connect(account4).placeBid(1, 1, 90);
  await taskAuction.connect(account5).placeBid(1, 1, 80);
  await taskAuction.connect(account4).placeBid(2, 1, 80);

  //Call end Auction at TaskAuction too soon to success
  await taskAuction.endAuction();

  //increase time
  await time.increase(2000);
  await taskAuction.endAuction();

  //Filter EndAuction event
  filterEndAuction = taskAuction.filters.EndAuction(null, 1, null, null);

  const resultsFilter = await taskAuction.queryFilter(filterEndAuction);
  resultsFilter.map((event) => {
    event = event.args;
    let EndAuctionTask = {
      batchTaskState: event.batchTaskState,
      batchTaskId: event.batchTaskId,
      auctionTask: event.auctionTask,
      endTime: event.endTime,
    };
    console.log("EndAuctionTask", EndAuctionTask);
  });
  //After endAuction account4 must get back money
  //Account5 calculate amount token need to commit
  await creditScore.calculateCommitmentToken(account5.address);
  filterCommitToken = creditScore.filters.CalculateCommitmentToken(
    account5.address,
    null
  );
  const resultsEvent = await creditScore.queryFilter(filterCommitToken);

  console.log("commitment Token account5", resultsEvent[0].args.value);
  //Account 5 assigned Task1 and have permission to call receive task later
  await taskManager
    .connect(account5)
    .receiveTask(1, resultsEvent[0].args.value);

  //User submit TaskResult
  await taskManager.connect(account5).submitTaskResult(1);

  //Reviewer submit review Result
  //Reviewer of task1 is account3 70% task Done
  await taskManager.connect(account3).submitReview(1, 70);

  //Todo: Some one want to extend their task

  //Check money payback sucessful
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
