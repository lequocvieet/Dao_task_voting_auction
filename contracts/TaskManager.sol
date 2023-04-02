// Solidity version used for the contract
pragma solidity ^0.8.17;
import "./interfaces/ITaskManager.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ITaskAuction.sol";
import "./interfaces/IBatchTaskVoting.sol";
import "./interfaces/ICreditScore.sol";
import "./interfaces/IBankManager.sol";
import "hardhat/console.sol";

//Todo: receive money bid at taskAuction but pay back at TaskManager
//Todo=> move all things relate to money to BankManager in ver2
//Todo: change ETH to own token from bank ver2
contract TaskManager is ITaskManager, Ownable {
    ITaskAuction public taskAuction;

    IBatchTaskVoting public batchTaskVoting;

    ICreditScore public creditScore;

    IBankManager public bankManager;

    address public tokenAddress;

    uint public pollCount;

    uint public batchTaskCount;

    uint public taskCount;

    // Array to store all the tasks created
    Task[] public tasks;

    //Array store all polls
    Poll[] public polls;

    //Array to store all batch task created
    BatchTask[] public batchTasks;

    mapping(uint => Task) taskIdToTask;

    mapping(uint => Poll) pollIdToPoll;

    mapping(uint => BatchTask) batchTaskIdToBatchTask;

    event PollInit(
        uint pollId,
        address indexed pollOwner,
        POLL_STATE pollState
    );
    event BatchTaskInit(
        uint batchTaskId,
        uint pollId,
        BATCH_TASK_STATE batchTaskState
    );
    event TaskInit(
        uint batchTaskId,
        uint point,
        uint reward,
        uint minReward,
        address indexed reporter,
        address indexed reviewer,
        TASK_STATE taskState
    );
    event OpenPollForVote(
        uint _pollId,
        uint _voteDuration,
        uint timeOpenPollVote,
        address indexed pollOwner,
        POLL_STATE pollState
    );

    event OpenBatchTaskForAuction(
        uint batchTaskID,
        uint auctionDuration,
        uint timeOpen, //Todo: indexed caller
        BATCH_TASK_STATE batchTaskState
    );

    event AssignTask(
        uint taskId,
        uint reward,
        address indexed doer,
        TASK_STATE taskState
    );

    event ReceiveTask(
        uint taskId,
        uint timeReceive,
        address indexed doer,
        TASK_STATE taskState,
        uint commitValue
    );

    event SubmitTaskResult(
        uint taskId,
        uint timeSubmit,
        address indexed doer,
        TASK_STATE taskState
    );

    event SubmitReview(
        uint taskId,
        uint percentageDone,
        address indexed reviewer,
        TASK_STATE taskState,
        uint timeSubmit
        //Money transfer emit at bankManager.sol
    );

    event UpdateTask(
        uint taskId,
        uint newPoint,
        address indexed updater,
        uint timeUpdate
    );

    modifier checkBatchTaskState(
        BATCH_TASK_STATE requiredState,
        uint _BatchTaskID
    ) {
        require(
            batchTaskIdToBatchTask[_BatchTaskID].batchTaskState ==
                requiredState,
            "Error: Invalid Batch Task State"
        );
        _;
    }

    modifier checkTaskState(TASK_STATE requiredState, uint _taskID) {
        require(
            taskIdToTask[_taskID].taskState == requiredState,
            "Error: Invalid Task State"
        );
        _;
    }

    function setTaskAuction(address _taskAuctionAddress) external onlyOwner {
        taskAuction = ITaskAuction(_taskAuctionAddress);
    }

    function setBatchTaskVoting(
        address _batchTaskVotingAddress
    ) external onlyOwner {
        batchTaskVoting = IBatchTaskVoting(_batchTaskVotingAddress);
    }

    function setCreditScore(address _creditScoreAddress) external onlyOwner {
        creditScore = ICreditScore(_creditScoreAddress);
    }

    function setBankManager(address _bankManagerAddress) external onlyOwner {
        bankManager = IBankManager(_bankManagerAddress);
    }

    function chooseToken(address _tokenAddress) external onlyOwner {
        tokenAddress = _tokenAddress;
    }

    //Todo: onlycall by backend with signed signature
    function initPoll(address _pollOwner) external {
        Poll memory newPoll;
        pollCount++;
        newPoll.pollId = pollCount;
        newPoll.pollOwner = _pollOwner;
        newPoll.pollState = POLL_STATE.CREATED;
        pollIdToPoll[pollCount] = newPoll;
        polls.push(newPoll);
        emit PollInit(pollCount, _pollOwner, POLL_STATE.CREATED);
    }

    //Todo: onlycall by backend with signed signature
    function initBatchTask(uint _pollId) external {
        BatchTask memory newBatchTask;
        batchTaskCount++;
        newBatchTask.batchTaskId = batchTaskCount;
        newBatchTask.batchTaskState = BATCH_TASK_STATE.CREATED;
        batchTaskIdToBatchTask[batchTaskCount] = newBatchTask;
        pollIdToPoll[_pollId].batchTaskIds.push(batchTaskCount);
        emit BatchTaskInit(batchTaskCount, _pollId, BATCH_TASK_STATE.CREATED);
    }

    //Todo: onlycall by backend with signed signature
    function initTask(
        uint _batchTaskId,
        uint _point, //point is caculated by durations 1 point=4 hour
        uint _reward,
        uint _minReward,
        address _reporter,
        address _reviewer
    ) external {
        Task memory newTask;
        taskCount++;
        newTask.taskId = taskCount;
        newTask.point = _point;
        newTask.reward = _reward;
        newTask.minReward = _minReward;
        newTask.reporter = _reporter;
        newTask.reviewer = _reviewer;
        newTask.taskState = TASK_STATE.CREATED;
        batchTaskIdToBatchTask[_batchTaskId].taskIds.push(taskCount);
        taskIdToTask[taskCount] = newTask;
        emit TaskInit(
            _batchTaskId,
            _point,
            _reward,
            _minReward,
            _reporter,
            _reviewer,
            TASK_STATE.CREATED
        );
    }

    //Open Poll for vote
    //Todo:should call by onlyOwner?
    //Todo: require state
    //Todo: check pollId exist
    function openPollForVote(uint _pollId, uint _voteDuration) public {
        pollIdToPoll[_pollId].pollState = POLL_STATE.OPENFORVOTE;
        batchTaskVoting.openPollForVote(
            _pollId,
            _voteDuration,
            pollIdToPoll[_pollId].batchTaskIds
        );
        emit OpenPollForVote(
            _pollId,
            _voteDuration,
            block.timestamp,
            msg.sender,
            POLL_STATE.OPENFORVOTE
        );
    }

    //Todo:OnlyCall by BatchTaskVoting after done vote
    function initBatchTaskAuction(uint _batchTaskId) external {
        batchTaskIdToBatchTask[_batchTaskId].batchTaskState = BATCH_TASK_STATE
            .VOTED;
    }

    //Todo: only call by who?
    //Todo: checkID exist
    function openBatchTaskForAuction(
        uint _batchTaskID,
        uint _auctionDuration
    ) external checkBatchTaskState(BATCH_TASK_STATE.VOTED, _batchTaskID) {
        batchTaskIdToBatchTask[_batchTaskID].batchTaskState = BATCH_TASK_STATE
            .OPENFORAUCTION;
        Task[] memory auctionTasks;
        for (
            uint i = 0;
            i < batchTaskIdToBatchTask[_batchTaskID].taskIds.length;
            i++
        ) {
            auctionTasks[i] = taskIdToTask[
                batchTaskIdToBatchTask[_batchTaskID].taskIds[i]
            ];
        }
        taskAuction.openTaskForAuction(
            auctionTasks,
            _batchTaskID,
            _auctionDuration
        );
        emit OpenBatchTaskForAuction(
            _batchTaskID,
            _auctionDuration,
            block.timestamp,
            BATCH_TASK_STATE.OPENFORAUCTION
        );
    }

    //Todo:OnlyCall by TaskAuction after done auction
    function assignTask(
        ITaskAuction.AuctionTask memory doneAuctionTask
    ) public {
        taskIdToTask[doneAuctionTask.taskId].reward = doneAuctionTask.reward;
        taskIdToTask[doneAuctionTask.taskId].doer = doneAuctionTask.doer;
        taskIdToTask[doneAuctionTask.taskId].taskState = TASK_STATE.ASSIGNED;
        emit AssignTask(
            doneAuctionTask.taskId,
            doneAuctionTask.reward,
            doneAuctionTask.doer,
            TASK_STATE.ASSIGNED
        );
    }

    /** 
    //Only doer can call receive task after assigned in auction
    //require task state=ASSIGNED
    //require send a commitment token base on their creditscore
    */
    function receiveTask(
        uint _taskId,
        uint _commitValue
    ) external checkTaskState(TASK_STATE.ASSIGNED, _taskId) {
        require(msg.sender == taskIdToTask[_taskId].doer, "Only doer can call");
        require(taskIdToTask[_taskId].taskId == _taskId, "taskID not found");
        uint commitmentToken = creditScore.calculateCommitmentToken(msg.sender);
        require(
            bankManager.balanceOf(msg.sender, tokenAddress) >= _commitValue,
            "Your balance not enough"
        );
        require(
            _commitValue >= commitmentToken,
            "Not provide enough money to receive task!"
        );
        taskIdToTask[_taskId].taskState = TASK_STATE.RECEIVED;
        taskIdToTask[_taskId].timeDoerReceive = block.timestamp;
        emit ReceiveTask(
            _taskId,
            block.timestamp,
            msg.sender,
            TASK_STATE.RECEIVED,
            _commitValue
        );
    }

    /** 
    //require submit time > time task assigned(no need because changes by state)
    //Todo: if submit time> time task assigned+deadline=>task fail without revieww
    //Only doer can submit
    //require task stated==RECEIVED
    */
    function submitTaskResult(
        uint _taskId
    ) external checkTaskState(TASK_STATE.RECEIVED, _taskId) {
        require(taskIdToTask[_taskId].taskId == _taskId, "taskID not found");
        require(msg.sender == taskIdToTask[_taskId].doer, "Only doer can call");
        taskIdToTask[_taskId].taskState = TASK_STATE.SUBMITTED;
        emit SubmitTaskResult(
            _taskId,
            block.timestamp,
            msg.sender,
            TASK_STATE.SUBMITTED
        );
    }

    /** 
    //Only reviewer can call to submit revieww result of particular doer
    //require task state=SUBMITED
    //Reviewer choose % work load done to decide which %reward would be send to doer
    //After Submit revieww=> transfer money for doer
    //=> change task state to REVIEWED
    //=> Todo: leaf over money would send to bank manager reserve for many tasks later
    */
    function submitReview(
        uint _taskId,
        uint percentageDone //ex:100==100%
    ) external checkTaskState(TASK_STATE.SUBMITTED, _taskId) {
        require(
            msg.sender == taskIdToTask[_taskId].reviewer,
            "Only reviewer can call"
        );
        require(
            taskIdToTask[_taskId].taskId == _taskId,
            "taskID or batchTaskID not found"
        );
        console.log("reward", taskIdToTask[_taskId].reward);
        uint payReward = (taskIdToTask[_taskId].reward * percentageDone) / 100; //in wei or decimal 10^18
        //transfer reward and commitmentToken deposit before
        bankManager.transfer(
            tokenAddress,
            taskIdToTask[_taskId].doer,
            payReward
        );

        //update taskDone history to CreditScore for future calculation
        creditScore.saveTaskDone(
            _taskId,
            taskIdToTask[_taskId].doer,
            percentageDone
        );
        taskIdToTask[_taskId].taskState = TASK_STATE.REVIEWED;
        emit SubmitReview(
            _taskId,
            percentageDone,
            msg.sender,
            TASK_STATE.REVIEWED,
            block.timestamp
        );
    }

    /** 
    //Can call by:
    //If doer want to extends the duration=> send money to extends
    //If reviewer want to extends => ok not send money
    //Require task state=RECEIVED
    */
    function updateTask(
        uint _taskId,
        uint _newPoint //point =duration
    ) external checkTaskState(TASK_STATE.RECEIVED, _taskId) {
        require(
            msg.sender == taskIdToTask[_taskId].reviewer ||
                msg.sender == taskIdToTask[_taskId].doer,
            "Only doer or reviewer can call"
        );
        if (msg.sender == taskIdToTask[_taskId].reviewer) {
            taskIdToTask[_taskId].point = _newPoint;
        }
        if (msg.sender == taskIdToTask[_taskId].doer) {
            taskIdToTask[_taskId].point = _newPoint;
            //Todo: require pay money to extend their task
        }
        emit UpdateTask(_taskId, _newPoint, msg.sender, block.timestamp);
    }

    function getAllBatchTaskByPollID(
        uint _pollID
    ) public view returns (BatchTask[] memory) {
        BatchTask[] memory listBatchTasks = new BatchTask[](
            pollIdToPoll[_pollID].batchTaskIds.length
        );
        for (uint i = 0; i < pollIdToPoll[_pollID].batchTaskIds.length; i++) {
            listBatchTasks[i] = batchTaskIdToBatchTask[
                pollIdToPoll[_pollID].batchTaskIds[i]
            ];
        }
        return listBatchTasks;
    }

    function getAllPoll() public view returns (Poll[] memory) {
        Poll[] memory listPolls = new Poll[](pollCount);
        for (uint i = 0; i < pollCount; i++) {
            listPolls[i] = pollIdToPoll[i + 1];
        }
        return listPolls;
    }
}
