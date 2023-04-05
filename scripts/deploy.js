const hre = require("hardhat");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");
const fs = require("fs");

async function main() {
  //Setup account
  var [contract_owner, pollOwner, reporter, reviewer, bidder, pic] =
    await ethers.getSigners();

  console.log("contract owner", contract_owner.address);
  console.log("pollOwner", pollOwner.address);
  console.log("reporter", reporter.address);
  console.log("reviewer", reviewer.address);
  console.log("bidder", bidder.address);
  console.log("pic", pic.address);

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
  savebuildFiles(taskManager, "TaskManager");

  //Deploy BatchTaskVoting
  BatchTaskVoting = await hre.ethers.getContractFactory("BatchTaskVoting");
  batchTaskVoting = await BatchTaskVoting.deploy();
  await batchTaskVoting.deployed();
  console.log("BatchTaskVoting deploy at:", batchTaskVoting.address);
  savebuildFiles(batchTaskVoting, "BatchTaskVoting");

  //Deploy TaskAuction
  TaskAuction = await hre.ethers.getContractFactory("TaskAuction");
  taskAuction = await TaskAuction.deploy();
  await batchTaskVoting.deployed();
  console.log("TaskAuction deploy at:", taskAuction.address);
  savebuildFiles(taskAuction, "TaskAuction");

  //Deploy CreditScore
  CreditScore = await hre.ethers.getContractFactory("CreditScore");
  creditScore = await CreditScore.deploy();
  await creditScore.deployed();
  console.log("CreditScore deploy at:", creditScore.address);
  savebuildFiles(creditScore, "CreditScore");

  //Deploy Token.sol
  Token = await hre.ethers.getContractFactory("Token");
  token = await Token.deploy("VNP", "VNP");
  await token.deployed();
  console.log("Token deploy at:", token.address);
  savebuildFiles(token, "Token");

  //Deploy BankManager.sol
  BankManager = await hre.ethers.getContractFactory("BankManager");
  bankManager = await BankManager.deploy();
  await bankManager.deployed();
  console.log("BankManager deploy at:", bankManager.address);
  savebuildFiles(bankManager, "BankManager");

  //------------------------------------------INIT--------------------------------------
  totalSupply = 1000; // 1000 Token
  fundPrice = 100; //bank mint 100 token for all account

  task1Reward = 20; //20 token
  task1MinReward = 5; //5 token
  task1Point = 4; //1 point=4hour

  task2Reward = 30; //30 token
  task2MinReward = 7; //7 token
  task2Point = 3; //1 point=4hour

  poll1VoteDuration = 100; //100s

  //SetUp interface variable
  await taskManager.setTaskAuction(taskAuction.address);
  await taskManager.setBankManager(bankManager.address);
  await taskManager.setBatchTaskVoting(batchTaskVoting.address);
  await taskManager.chooseToken(token.address);
  await taskManager.setCreditScore(creditScore.address);
  await taskManager.chooseToken(token.address);

  await taskAuction.setTaskManager(taskManager.address);
  await taskAuction.setBankManager(bankManager.address);
  await taskAuction.chooseToken(token.address);

  await batchTaskVoting.setTaskManager(taskManager.address);

  //BankManager mint token
  await bankManager.mint(
    token.address,
    bankManager.address,
    ethers.utils.parseEther(totalSupply.toString())
  );

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

  console.log(
    "Balance of Bank",
    await bankManager.balanceOf(bankManager.address, token.address)
  );
  console.log(
    "Balance of contract_owner",
    await bankManager.balanceOf(contract_owner.address, token.address)
  );
  console.log(
    "Balance of pollOwner",
    await bankManager.balanceOf(pollOwner.address, token.address)
  );
  console.log(
    "Balance of reporter",
    await bankManager.balanceOf(reporter.address, token.address)
  );
  console.log(
    "Balance of reviewer",
    await bankManager.balanceOf(reviewer.address, token.address)
  );
  console.log(
    "Balance of bidder",
    await bankManager.balanceOf(bidder.address, token.address)
  );
  console.log(
    "Balance of pic",
    await bankManager.balanceOf(pic.address, token.address)
  );

  //Init Data Poll BatchTask Task
  await taskManager.connect(contract_owner).initPoll(pollOwner.address);
  await taskManager.connect(contract_owner).initPoll(pollOwner.address);
  await taskManager.connect(contract_owner).initBatchTask(1); //batch1 poll1
  await taskManager.connect(contract_owner).initBatchTask(1); //batch2 poll2
  await taskManager
    .connect(contract_owner)
    .initTask(
      1,
      task1Point,
      task1Reward,
      task1MinReward,
      reporter.address,
      reviewer.address
    ); //task 1 batch1
  await taskManager
    .connect(contract_owner)
    .initTask(
      1,
      task2Point,
      task2Reward,
      task2MinReward,
      reporter.address,
      reviewer.address
    ); //task2 batch1
}

function savebuildFiles(contract, name) {
  const fs = require("fs");
  const contractsDir = __dirname + "/../contractsData";

  if (!fs.existsSync(contractsDir)) {
    fs.mkdirSync(contractsDir);
  }

  fs.writeFileSync(
    contractsDir + `/${name}-address.json`,
    JSON.stringify({ address: contract.address }, undefined, 2)
  );

  const contractArtifact = artifacts.readArtifactSync(name);

  fs.writeFileSync(
    contractsDir + `/${name}.json`,
    JSON.stringify(contractArtifact, null, 2)
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
