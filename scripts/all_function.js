const hre = require("hardhat");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");
const taskManagerAddress = require("../contractsData/TaskManager-address.json");
const batchTaskVotingAddress = require("../contractsData/BatchTaskVoting-address.json");
const taskAuctionAddress = require("../contractsData/TaskAuction-address.json");
const creditScoreAddress = require("../contractsData/CreditScore-address.json");
const bankManagerAddress = require("../contractsData/BankManager-address.json");
const tokenAddress = require("../contractsData/Token-address.json");

async function main() {
  //Get already deployed contract
  const TaskManager = await ethers.getContractFactory("TaskManager");
  const taskManager = TaskManager.attach(taskManagerAddress.address);

  const BatchTaskVoting = await ethers.getContractFactory("BatchTaskVoting");
  const batchTaskVoting = BatchTaskVoting.attach(
    batchTaskVotingAddress.address
  );

  const TaskAuction = await ethers.getContractFactory("TaskAuction");
  const taskAuction = TaskAuction.attach(taskAuctionAddress.address);

  const CreditScore = await ethers.getContractFactory("CreditScore");
  const creditScore = CreditScore.attach(creditScoreAddress.address);

  const BankManager = await ethers.getContractFactory("BankManager");
  const bankManager = BankManager.attach(bankManagerAddress.address);

  //All account
  var [contract_owner, pollOwner, reporter, reviewer, bidder, pic] =
    await ethers.getSigners();

  console.log("contract owner", contract_owner.address);
  console.log("account1", pollOwner.address);
  console.log("account2", reporter.address);
  console.log("account3", reviewer.address);
  console.log("bidder", bidder.address);
  console.log("account5", pic.address);

  //--------------------------------------------------ALL GET FUNCTION--------------------------------------

  let polls = await taskManager.getAllPoll();
  console.log("polls", polls);

  let pollsVoting = await batchTaskVoting.getAllPollVoting();
  console.log("pollsVoting", pollsVoting);

  let batchTasks = await taskManager.getAllBatchTaskByPollID(1);
  console.log("batchTasks", batchTasks);

  let batchTaskVotings = await batchTaskVoting.getAllBatchTaskVoting(1);
  console.log("batchTaskVoting", batchTaskVotings);

  let tasks = await taskManager.getAllTask(1);
  console.log("tasks", tasks);

  let batchTaskAuctions = await taskAuction.getAllBatchTaskAuction(1);
  console.log("batchTaskAuctions", batchTaskAuctions);

  let taskAuctions = await taskAuction.getAllTaskAuction(1);
  console.log("taskAuctions", taskAuctions);

  //------------------------------------------VOTING FUNCTION --------------------------------------

  //openPollForVote(pollId, voteDuration)
  await taskManager.connect(pollOwner).openPollForVote(1, 1000);

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

  //bidder vote on batchTask2
  await batchTaskVoting.connect(bidder).voteOnBatchTask(2, 1);

  //vote again change to batchTask1
  await batchTaskVoting.connect(bidder).voteOnBatchTask(1, 1);

  //pic vote on batchTask1
  await batchTaskVoting.connect(pic).voteOnBatchTask(1, 1);

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
  //account 5 place bid 80 wei on same task to kick bidder out
  await taskAuction.connect(bidder).placeBid(1, 1, 90);
  await taskAuction.connect(pic).placeBid(1, 1, 80);
  await taskAuction.connect(bidder).placeBid(2, 1, 80);

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
  //After endAuction bidder must get back money
  //pic calculate amount token need to commit
  await creditScore.calculateCommitmentToken(pic.address);
  filterCommitToken = creditScore.filters.CalculateCommitmentToken(
    pic.address,
    null
  );
  const resultsEvent = await creditScore.queryFilter(filterCommitToken);

  console.log("commitment Token pic", resultsEvent[0].args.value);
  //Account 5 assigned Task1 and have permission to call receive task later
  await taskManager.connect(pic).receiveTask(1, resultsEvent[0].args.value);

  //User submit TaskResult
  await taskManager.connect(pic).submitTaskResult(1);

  //Reviewer submit review Result
  //Reviewer of task1 is reviewer 70% task Done
  await taskManager.connect(reviewer).submitReview(1, 70);

  //Todo: Some one want to extend their task

  //Check money payback sucessful
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
