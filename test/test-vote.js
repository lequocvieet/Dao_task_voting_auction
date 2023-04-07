const { expect } = require("chai");
const { ethers } = require("hardhat");
var assert = require("assert");

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
  });
  it("Should revert if vote on wrong pollId or wrong batchTask id", async function () {
    //User vote on batchTask 1 of poll1
    let pollId = 100;
    let batchTaskId = 1;
    await expect(
      batchTaskVoting.connect(pollOwner).voteOnBatchTask(batchTaskId, pollId)
    ).to.be.revertedWith("Poll not exist");

    pollId = 1;
    batchTaskId = 100;
    await expect(
      batchTaskVoting.connect(pollOwner).voteOnBatchTask(batchTaskId, pollId)
    ).to.be.revertedWith("batch task id not exist");
  });

  it("Should revert if poll duration is due", async function () {
    //User vote on batchTask 1 of poll1
    let pollId = 1;
    let batchTaskId = 1;

    // Increase block time by 1 day
    await network.provider.send("evm_increaseTime", [86400]);

    await expect(
      batchTaskVoting.connect(pollOwner).voteOnBatchTask(batchTaskId, pollId)
    ).to.be.revertedWith("Poll Voting is end");
  });

  it("Should revert if vote again but not change vote choice", async function () {
    //User vote on batchTask 1 of poll1
    let pollId = 1;
    let batchTaskId = 1;
    //vote first time
    tx = await batchTaskVoting
      .connect(pollOwner)
      .voteOnBatchTask(batchTaskId, pollId);
    //vote again but not change vote choice
    await expect(
      batchTaskVoting.connect(pollOwner).voteOnBatchTask(batchTaskId, pollId)
    ).to.be.revertedWith("You not change your vote");
  });
  it("Should allow multi user vote and vote again many time ", async function () {
    //User vote on batchTask 1 of poll1
    let pollId = 1;
    let batchTaskId1 = 1;
    let batchtaskId2 = 2;
    //vote first time
    tx = await batchTaskVoting
      .connect(pollOwner)
      .voteOnBatchTask(batchTaskId1, pollId);
    //vote again, change vote choice to batchTask2
    tx = await batchTaskVoting
      .connect(pollOwner)
      .voteOnBatchTask(batchtaskId2, pollId);

    //vote again, change vote choice to batchTask1
    tx = await batchTaskVoting
      .connect(pollOwner)
      .voteOnBatchTask(batchTaskId1, pollId);

    //vote again, change vote choice to batchTask2
    tx = await batchTaskVoting
      .connect(pollOwner)
      .voteOnBatchTask(batchtaskId2, pollId);

    //pic vote batchTask2
    tx = await batchTaskVoting
      .connect(pic)
      .voteOnBatchTask(batchtaskId2, pollId);

    //pic change vote to batchTask1
    tx = await batchTaskVoting
      .connect(pic)
      .voteOnBatchTask(batchTaskId1, pollId);

    //after all change check all batch in poll1
    let batchTasks = await batchTaskVoting.getAllBatchTaskVoting(1);
    assert.equal(
      batchTasks.length,
      2,
      "Incorrect number of batch tasks in poll"
    );

    assert.equal(batchTasks[0].result, 0, "Incorrect result");
    assert.equal(batchTasks[0].voters.length, 2, "Incorrect number voter");

    assert.equal(batchTasks[1].result, 0, "Incorrect result");
    assert.equal(batchTasks[1].voters.length, 2, "Incorrect number voter");
  });
  it("Should emit notify if  endvote soon", async function () {
    //User vote on batchTask 1 of poll1
    let pollId = 1;
    let batchTaskId = 1;
    tx = await batchTaskVoting
      .connect(pollOwner)
      .voteOnBatchTask(batchTaskId, pollId);

    tx = await batchTaskVoting.connect(pic).endVote();
    await expect(tx)
      .to.emit(batchTaskVoting, "Notify")
      .withArgs("There are no Poll Voting can end at the moment");
  });

  it("Should endvote ", async function () {
    //User vote on batchTask 1 of poll1
    let pollId = 1;
    let batchTaskId = 1;
    tx = await batchTaskVoting
      .connect(pollOwner)
      .voteOnBatchTask(batchTaskId, pollId);
    // Increase block time by 1 day
    await network.provider.send("evm_increaseTime", [86400]);

    tx = await batchTaskVoting.connect(pic).endVote();
    await expect(tx).to.emit(batchTaskVoting, "EndVote");
  });
});
