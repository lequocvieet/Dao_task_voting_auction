const hre = require("hardhat");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");
const taskManagerAddress = require("../contractsData/TaskManager-address.json");
const batchTaskVotingAddress = require("../contractsData/BatchTaskVoting-address.json");
const taskAuctionAddress = require("../contractsData/TaskAuction-address.json");
const creditScoreAddress = require("../contractsData/CreditScore-address.json");
const bankManagerAddress = require("../contractsData/BankManager-address.json");
const tokenAddress = require("../contractsData/Token-address.json");
const { EpochTimeToDate } = require("../scripts/helper_function");

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
  await taskManager.connect(pollOwner).openPollForVote(1, 1000); //poll1

  //Filter OpenPollForVote event
  let allPollOpened = [];
  filterOpenVote = taskManager.filters.OpenPollForVote(
    null,
    null,
    null,
    null,
    null
  );
  resultsfilterOpenVote = await taskManager.queryFilter(filterOpenVote);
  resultsfilterOpenVote.map((event) => {
    event = event.args;
    let pollOpened = {
      pollId: event._pollId.toString(),
      voteDuration: event._voteDuration,
      timeOpen: EpochTimeToDate(event.timeOpenPollVote),
      pollOwner: event.pollOwner,
      POLL_STATE: event.pollState,
    };
    allPollOpened.push(pollOpened);
  });
  console.log("all Poll Opened", allPollOpened);

  //bidder vote on batchTask2
  await batchTaskVoting.connect(bidder).voteOnBatchTask(2, 1);

  //bidder vote again change to batchTask1
  await batchTaskVoting.connect(bidder).voteOnBatchTask(1, 1);

  //pic vote on batchTask1
  await batchTaskVoting.connect(pic).voteOnBatchTask(1, 1);

  //call endvote at batchTaskVoting too soon
  await batchTaskVoting.endVote();

  //Increase Time then call endVote again
  await time.increase(2000);
  await batchTaskVoting.endVote();

  //Filter all EndVote event
  let PollEndeds = [];
  filter = batchTaskVoting.filters.EndVote(null, null, null, null);
  results = await batchTaskVoting.queryFilter(filter);
  results.map((event) => {
    event = event.args;
    let pollEnded = {
      pollId: event.pollId.toString(),
      POLL_STATE: event.pollState,
      batchTaskWinVote: event.batchWinVote,
      endTime: EpochTimeToDate(event.endTime),
    };
    PollEndeds.push(pollEnded);
  });
  console.log("PollEndeds", PollEndeds);

  // //------------------------------------------AUCTION FUNCTION--------------------------------------

  //open for Auction poll 1 batchTask 1  with 1000s duration
  await taskManager.openBatchTaskForAuction(1, 1, 1000);

  //Filter OpenTaskForAuction event of batch1
  let batchTaskOnAuctions = [];
  filter = taskAuction.filters.OpenTaskForAuction(1, null, null, null);
  results = await taskAuction.queryFilter(filter);
  results.map((event) => {
    event = event.args;
    let batchTaskOnAuction = {
      batchTaskId: event._batchTaskId.toString(),
      auctionDuration: event._auctionDuration,
      taskOnAuction: event.auctionTask,
      BATCH_TASK_STATE: event.batchTaskState,
      endTime: EpochTimeToDate(event.timeStart),
    };
    batchTaskOnAuctions.push(batchTaskOnAuction);
  });
  console.log("batchTaskOnAuctions", batchTaskOnAuctions);

  //bidder place bid 15 token on task1 of batchTask1(current reward is 20)
  //pic place bid 10 token on same task to kick bidder out
  await taskAuction.connect(bidder).placeBid(1, 1, 15);
  await taskAuction.connect(pic).placeBid(1, 1, 10);
  //pic bid again with 5 token
  await taskAuction.connect(pic).placeBid(1, 1, 5);

  //filter PlaceBid event of task1
  let bids = [];
  filter = taskAuction.filters.PlaceBid(1, null, null, null, null);
  results = await taskAuction.queryFilter(filter);
  results.map((event) => {
    event = event.args;
    let bid = {
      taskID: event._taskID.toString(),
      batchTaskID: event._batchTaskID.toString(),
      auctionTask: event.auctionTask,
      bid: event.bid,
      bidTime: EpochTimeToDate(event.bidTime),
    };
    bids.push(bid);
  });
  console.log("bids", bids);

  //Call end Auction at TaskAuction too soon to success
  await taskAuction.endAuction();

  //increase time
  await time.increase(2000);
  await taskAuction.endAuction();

  //Filter EndAuction event of batchTask1
  let endAuctionTasks = [];
  filter = taskAuction.filters.EndAuction(1, null, null, null);
  results = await taskAuction.queryFilter(filter);
  results.map((event) => {
    event = event.args;
    let endAuctionTask = {
      batchTaskId: event.batchTaskId,
      batchTaskState: event.batchTaskState,
      assignedTask: event.assignedTask,
      endTime: EpochTimeToDate(event.endTime),
    };
    endAuctionTasks.push(endAuctionTask);
  });
  console.log("endAuctionTasks", endAuctionTasks);

  //After endAuction bidder must get back money
  //pic calculate amount token need to commit
  await creditScore.calculateCommitmentToken(pic.address);
  filterCommitToken = creditScore.filters.CalculateCommitmentToken(
    pic.address,
    null
  );
  const resultsEvent = await creditScore.queryFilter(filterCommitToken);

  console.log("commitment Token pic", resultsEvent[0].args.value);
  //pic get assigned Task1 and have permission to call receive task later
  await taskManager.connect(pic).receiveTask(1, resultsEvent[0].args.value);

  //User submit TaskResult
  await taskManager.connect(pic).submitTaskResult(1);

  //Reviewer submit review Result
  //Reviewer of task1 is reviewer 70% task Done
  await taskManager.connect(reviewer).submitReview(1, 70);

  //Todo: Some one want to extend their task

  //Todo: Check money payback
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
