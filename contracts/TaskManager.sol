pragma solidity ^0.8.17;
import "./interfaces/ITaskManager.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ITaskAuction.sol";
import "./interfaces/IBatchTaskVoting.sol";
import "./interfaces/ICreditScore.sol";
import "./interfaces/IBankManager.sol";
import "hardhat/console.sol";

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

    mapping(uint => Task) public taskIdToTask;

    mapping(uint => Poll) public pollIdToPoll;

    mapping(uint => BatchTask) public batchTaskIdToBatchTask;

    event PollInit(
        uint indexed pollId,
        address indexed pollOwner,
        POLL_STATE pollState
    );
    event BatchTaskInit(
        uint indexed batchTaskId,
        uint indexed pollId,
        BATCH_TASK_STATE batchTaskState
    );
    event TaskInit(
        uint taskId,
        uint indexed batchTaskId,
        uint point,
        uint reward,
        uint minReward,
        address indexed reporter,
        address indexed reviewer,
        TASK_STATE taskState
    );
    event OpenPollForVote(
        uint indexed _pollId,
        uint _voteDuration,
        uint timeOpenPollVote,
        address indexed pollOwner,
        POLL_STATE pollState
    );

    event OpenBatchTaskForAuction(
        uint indexed batchTaskID,
        uint auctionDuration,
        uint timeOpen, //Todo: indexed caller
        BATCH_TASK_STATE batchTaskState
    );

    event AssignTask(
        uint indexed taskId,
        uint reward,
        address indexed doer,
        TASK_STATE taskState
    );

    event ReceiveTask(
        uint indexed taskId,
        uint timeReceive,
        address indexed doer,
        TASK_STATE taskState,
        uint commitValue
    );

    event SubmitTaskResult(
        uint indexed taskId,
        uint timeSubmit,
        address indexed doer,
        TASK_STATE taskState
    );

    event SubmitReview(
        uint indexed taskId,
        uint percentageDone,
        address indexed reviewer,
        TASK_STATE taskState,
        uint timeSubmit
        //Money transfer emit at bankManager.sol
    );

    event UpdateTask(
        uint indexed taskId,
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

    modifier checkPollState(POLL_STATE requiredState, uint _pollID) {
        require(
            pollIdToPoll[_pollID].pollOwner != address(0),
            "Poll not exist!"
        );
        require(
            pollIdToPoll[_pollID].pollState == requiredState,
            "Error: Invalid Poll State"
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
        require(_pollOwner != address(0), "Wrong poll owner address");
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
    function initBatchTask(
        uint _pollId
    ) external checkPollState(POLL_STATE.CREATED, _pollId) {
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
    ) external checkBatchTaskState(BATCH_TASK_STATE.CREATED, _batchTaskId) {
        require(
            _reporter != address(0) && _reviewer != address(0),
            "Wrong address reporter or reviewer!"
        );
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
            taskCount,
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
    function openPollForVote(
        uint _pollId,
        uint _voteDuration
    ) public checkPollState(POLL_STATE.CREATED, _pollId) {
        require(
            msg.sender == pollIdToPoll[_pollId].pollOwner,
            "You not own this Poll"
        );
        require(_voteDuration > 0, "vote duration must be positive");
        require(
            pollIdToPoll[_pollId].batchTaskIds.length > 1,
            "Poll empty or has only 1 batch, no need to vote!"
        );
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
            pollIdToPoll[_pollId].pollState
        );
    }

    //Only call by BatchTaskVoting after done vote
    function initBatchTaskAuction(uint _batchTaskId) external {
        require(
            msg.sender == address(batchTaskVoting),
            "Only call by BatchTaskVoting"
        );
        batchTaskIdToBatchTask[_batchTaskId].batchTaskState = BATCH_TASK_STATE
            .VOTED;
    }

    //Todo: only call by batchTask Owner
    function openBatchTaskForAuction(
        uint _pollID,
        uint _batchTaskID,
        uint _auctionDuration
    ) external {
        if (pollIdToPoll[_pollID].batchTaskIds.length == 1) {
            //Poll has only 1 batch
            batchTaskIdToBatchTask[_batchTaskID]
                .batchTaskState = BATCH_TASK_STATE.VOTED;
        }
        require(
            batchTaskIdToBatchTask[_batchTaskID].batchTaskState ==
                BATCH_TASK_STATE.VOTED,
            "Error: Invalid Batch Task State"
        );
        batchTaskIdToBatchTask[_batchTaskID].batchTaskState = BATCH_TASK_STATE
            .OPENFORAUCTION;
        require(
            batchTaskIdToBatchTask[_batchTaskID].taskIds.length > 0,
            "There are no task in this batchTask"
        );
        Task[] memory auctionTasks = new Task[](
            batchTaskIdToBatchTask[_batchTaskID].taskIds.length
        );
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
            _pollID,
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

    //OnlyCall by TaskAuction after done auction
    function assignTask(
        ITaskAuction.AuctionTask memory doneAuctionTask
    ) public {
        require(msg.sender == address(taskAuction), "Only call by TaskAuction");
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
        bankManager.transfer(
            msg.sender,
            tokenAddress,
            address(bankManager),
            _commitValue
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
    //=> Todo: leaf over money would send to expecial pool reserve for many tasks later
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
            address(bankManager),
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

    function getAllTask(uint _batchTaskId) public view returns (Task[] memory) {
        Task[] memory listTasks = new Task[](
            batchTaskIdToBatchTask[_batchTaskId].taskIds.length
        );
        for (
            uint i = 0;
            i < batchTaskIdToBatchTask[_batchTaskId].taskIds.length;
            i++
        ) {
            listTasks[i] = taskIdToTask[
                batchTaskIdToBatchTask[_batchTaskId].taskIds[i]
            ];
        }
        return listTasks;
    }
}
