const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Test Init and Open Poll", function () {
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
  });

  it("should init new poll", async function () {
    let pollCount = 3;
    //contract owner create new poll with pollOwner
    tx = await taskManager.connect(contract_owner).initPoll(pollOwner.address);
    await expect(tx)
      .to.emit(taskManager, "PollInit")
      .withArgs(pollCount, pollOwner.address, POLL_STATE.CREATED);
    pollCount++;

    //init more poll
    tx = await taskManager.connect(contract_owner).initPoll(pollOwner.address);
    await expect(tx)
      .to.emit(taskManager, "PollInit")
      .withArgs(pollCount, pollOwner.address, POLL_STATE.CREATED);
  });

  it("should init new batchTask", async function () {
    let bacthTaskCount = 3;
    //contract owner create new batchsTask for poll1
    tx = await taskManager.connect(contract_owner).initBatchTask(1);
    await expect(tx)
      .to.emit(taskManager, "BatchTaskInit")
      .withArgs(bacthTaskCount, 1, BATCH_TASK_STATE.CREATED);
    bacthTaskCount++;

    //init more batchTask
    tx = await taskManager.connect(contract_owner).initBatchTask(1);
    await expect(tx)
      .to.emit(taskManager, "BatchTaskInit")
      .withArgs(bacthTaskCount, 1, BATCH_TASK_STATE.CREATED);
  });

  it("should init new Task", async function () {
    let taskCount = 3;
    let batchTaskId = 1;
    //contract owner create new task for batchTask1
    tx = await taskManager
      .connect(contract_owner)
      .initTask(
        batchTaskId,
        task1Point,
        task1Reward,
        task1MinReward,
        reporter.address,
        reviewer.address
      );
    await expect(tx)
      .to.emit(taskManager, "TaskInit")
      .withArgs(
        taskCount,
        batchTaskId,
        task1Point,
        task1Reward,
        task1MinReward,
        reporter.address,
        reviewer.address,
        TASK_STATE.CREATED
      );
    taskCount++;

    //init more Task
    tx = await taskManager
      .connect(contract_owner)
      .initTask(
        batchTaskId,
        task2Point,
        task2Reward,
        task2MinReward,
        reporter.address,
        reviewer.address
      );
    await expect(tx)
      .to.emit(taskManager, "TaskInit")
      .withArgs(
        taskCount,
        batchTaskId,
        task2Point,
        task2Reward,
        task2MinReward,
        reporter.address,
        reviewer.address,
        TASK_STATE.CREATED
      );
  });

  it("Poll Owner should open Poll For Vote", async function () {
    //Poll Owner open poll1 for Vote
    let pollId = 1;
    tx = await taskManager
      .connect(pollOwner)
      .openPollForVote(pollId, poll1VoteDuration);
    blockNumber = await ethers.provider.getBlockNumber(); // obtain current block number
    timestamp = (await ethers.provider.getBlock(blockNumber)).timestamp; // obtain current block timestamp
    await expect(tx)
      .to.emit(taskManager, "OpenPollForVote")
      .withArgs(
        pollId,
        poll1VoteDuration,
        timestamp,
        pollOwner.address,
        POLL_STATE.OPENFORVOTE
      );

    poll = await taskManager.getAllPoll();
    await expect(tx)
      .to.emit(batchTaskVoting, "OpenForVote")
      .withArgs(
        pollId,
        poll[0].batchTaskIds,
        poll1VoteDuration,
        POLL_STATE.OPENFORVOTE,
        timestamp
      );
  });

  it("Should revert if caller not pollOwner", async function () {
    //Poll Owner open poll1 for Vote
    let pollId = 1;
    await expect(
      taskManager.connect(reporter).openPollForVote(pollId, poll1VoteDuration)
    ).to.be.revertedWith("You not own this Poll");
  });
  it("Should revert if open poll for vote  again", async function () {
    //Poll Owner open poll1 for Vote
    let pollId = 1;
    //first time open=>ok
    await taskManager
      .connect(pollOwner)
      .openPollForVote(pollId, poll1VoteDuration);

    //open again=> revert
    await expect(
      taskManager.connect(pollOwner).openPollForVote(pollId, poll1VoteDuration)
    ).to.be.revertedWith("Error: Invalid Poll State");
  });
  it("Should revert if open wrong or not exist poll id", async function () {
    //Poll Owner open poll1 for Vote
    let pollId = 100;
    await expect(
      taskManager.connect(pollOwner).openPollForVote(pollId, poll1VoteDuration)
    ).to.be.revertedWith("Poll not exist!");
  });

  it("Should revert if vote duration wrong ", async function () {
    //Poll Owner open poll1 for Vote
    let pollId = 1;
    await expect(
      taskManager.connect(pollOwner).openPollForVote(pollId, 0)
    ).to.be.revertedWith("vote duration must be positive");
  });

  it("Should revert if open vote for empty poll", async function () {
    //Poll Owner open poll2 which is empty for Vote
    let pollId = 2;
    await expect(
      taskManager.connect(pollOwner).openPollForVote(pollId, poll2VoteDuration)
    ).to.be.revertedWith("Poll open must not be empty");
  });
});
