const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Test Voting", function () {
  beforeEach(async function () {
    //set up variables test
    [contract_owner, pollOwner, reporter, reviewer, bidder, pic] =
      await ethers.getSigners();

    totalSupply = 1000; // 1000 Token
    fundPrice = 100; //bank mint 100 token for all account
    task1Reward = 20; //20 token
    task1MinReward = 5; //5 token
    task1Point = 4; //1 point=4hour

    task2Reward = 30; //30 token
    task2MinReward = 7; //7 token
    task2Point = 3; //1 point=4hour

    poll1VoteDuration = 100; //100s
    poll2VoteDuration = 50; //50s

    POLL_STATE = {
      CREATED: 0,
      OPENFORVOTE: 1,
      VOTED: 2,
    };

    BATCH_TASK_STATE = {
      CREATED: 0,
      VOTED: 1,
      OPENFORAUCTION: 2,
    };

    TASK_STATE = {
      CREATED: 0,
      ASSIGNED: 1,
      RECEIVED: 2,
      SUBMITTED: 3,
      REVIEWED: 4,
    };

    //Deploy 6 contracts
    TaskManager = await hre.ethers.getContractFactory("TaskManager");
    taskManager = await TaskManager.deploy();
    await taskManager.deployed();

    BatchTaskVoting = await hre.ethers.getContractFactory("BatchTaskVoting");
    batchTaskVoting = await BatchTaskVoting.deploy();
    await batchTaskVoting.deployed();

    TaskAuction = await hre.ethers.getContractFactory("TaskAuction");
    taskAuction = await TaskAuction.deploy();
    await batchTaskVoting.deployed();

    CreditScore = await hre.ethers.getContractFactory("CreditScore");
    creditScore = await CreditScore.deploy();
    await creditScore.deployed();

    Token = await hre.ethers.getContractFactory("Token");
    token = await Token.deploy("VNP", "VNP");
    await token.deployed();

    BankManager = await hre.ethers.getContractFactory("BankManager");
    bankManager = await BankManager.deploy();
    await bankManager.deployed();

    await taskManager.setBatchTaskVoting(batchTaskVoting.address);

    //SetUp interface variable
    await taskManager.setTaskAuction(taskAuction.address);
    await taskManager.setBankManager(bankManager.address);
    await taskManager.chooseToken(token.address);
    await taskManager.setCreditScore(creditScore.address);

    await taskAuction.setTaskManager(taskManager.address);
    await taskAuction.setBankManager(bankManager.address);
    await taskAuction.chooseToken(token.address);

    await batchTaskVoting.setTaskManager(taskManager.address);

    //Mint Token
    await bankManager.mint(
      token.address,
      bankManager.address,
      ethers.utils.parseEther(totalSupply.toString())
    );
    await bankManager.mint(
      token.address,
      contract_owner.address,
      ethers.utils.parseEther(fundPrice.toString())
    );
    await bankManager.mint(
      token.address,
      pollOwner.address,
      ethers.utils.parseEther(fundPrice.toString())
    );
    await bankManager.mint(
      token.address,
      reporter.address,
      ethers.utils.parseEther(fundPrice.toString())
    );
    await bankManager.mint(
      token.address,
      reviewer.address,
      ethers.utils.parseEther(fundPrice.toString())
    );
    await bankManager.mint(
      token.address,
      bidder.address,
      ethers.utils.parseEther(fundPrice.toString())
    );
    await bankManager.mint(
      token.address,
      pic.address,
      ethers.utils.parseEther(fundPrice.toString())
    );

    //Init Data Poll BatchTask Task
    await taskManager.connect(contract_owner).initPoll(pollOwner.address);
    await taskManager.connect(contract_owner).initPoll(pollOwner.address);
    await taskManager.connect(contract_owner).initBatchTask(1);
    await taskManager.connect(contract_owner).initBatchTask(1);
    await taskManager
      .connect(contract_owner)
      .initTask(
        1,
        task1Point,
        task1Reward,
        task1MinReward,
        reporter.address,
        reviewer.address
      );
    await taskManager
      .connect(contract_owner)
      .initTask(
        1,
        task2Point,
        task2Reward,
        task2MinReward,
        reporter.address,
        reviewer.address
      );
    //Open poll 1 for vote
    await taskManager.connect(pollOwner).openPollForVote(1, poll1VoteDuration);

    // //Open Poll 2 for vote
    // await taskManager.connect(pollOwner).openPollForVote(2, poll2VoteDuration);
  });

  it("Should vote on batch Task", async function () {
    //User vote on batchTask 1 of poll1
    let pollId = 1;
    let batchTaskId = 1;
    tx = await batchTaskVoting
      .connect(pollOwner)
      .voteOnBatchTask(batchTaskId, pollId);
    blockNumber = await ethers.provider.getBlockNumber(); // obtain current block number
    timestamp = (await ethers.provider.getBlock(blockNumber)).timestamp; // obtain current block timestamp
    let allBatchTasks = await batchTaskVoting.getAllBatchTaskVoting(pollId); // //Open Poll 2 for vote
    console.log(allBatchTasks[0]);
    await expect(tx)
      .to.emit(batchTaskVoting, "VoteOnBatchTask")
      .withArgs(pollId, allBatchTasks[0], timestamp, pollOwner.address);
  });
});
