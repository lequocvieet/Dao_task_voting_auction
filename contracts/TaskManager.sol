// Solidity version used for the contract
pragma solidity ^0.8.17;
import "./interfaces/ITaskManager.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ITaskAuction.sol";
import "./interfaces/IBatchTaskVoting.sol";
import "./interfaces/ICreditScore.sol";
import "hardhat/console.sol";

// Contract definition
contract TaskManager is ITaskManager, Ownable {
    ITaskAuction public taskAuction;

    IBatchTaskVoting public batchTaskVoting;

    ICreditScore public creditScore;

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

    //Todo: onlycall by backend with signed signature
    function initPoll(address _pollOwner) external {
        Poll memory newPoll;
        pollCount++;
        newPoll.pollId = pollCount;
        newPoll.pollOwner = _pollOwner;
        pollIdToPoll[pollCount] = newPoll;
        polls.push(newPoll);
    }

    //Todo: onlycall by backend with signed signature
    function initBatchTask(uint _pollId) external {
        BatchTask memory newBatchTask;
        batchTaskCount++;
        newBatchTask.batchTaskId = batchTaskCount;
        batchTaskIdToBatchTask[batchTaskCount] = newBatchTask;
        pollIdToPoll[_pollId].batchTaskIds.push(batchTaskCount);
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
        batchTaskIdToBatchTask[_batchTaskId].taskIds.push(taskCount);
        taskIdToTask[taskCount] = newTask;
    }

    //Open Poll for vote
    //Todo:should call by onlyOwner?
    //Todo: require state
    //Todo: check pollId exist
    function openPollForVote(uint _pollId, uint _voteDuration) public {
        for (uint i = 0; i < pollIdToPoll[_pollId].batchTaskIds.length; i++) {
            batchTaskIdToBatchTask[pollIdToPoll[_pollId].batchTaskIds[i]]
                .batchTaskState = BATCH_TASK_STATE.OPENFORVOTE;

            batchTaskVoting.openForVote(
                pollIdToPoll[_pollId].batchTaskIds[i],
                _voteDuration
            );
        }
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
        for (
            uint i = 0;
            i < batchTaskIdToBatchTask[_batchTaskID].taskIds.length;
            i++
        ) {
            taskIdToTask[batchTaskIdToBatchTask[_batchTaskID].taskIds[i]]
                .taskState = TASK_STATE.OPENFORAUCTION;
            taskAuction.openTaskForAuction(
                taskIdToTask[batchTaskIdToBatchTask[_batchTaskID].taskIds[i]],
                _auctionDuration
            );
        }
    }

    //Todo:OnlyCall by TaskAuction after done auction
    function assignTask(
        ITaskAuction.AuctionTask memory doneAuctionTask
    ) public {
        taskIdToTask[doneAuctionTask.taskId].reward = doneAuctionTask.reward;
        taskIdToTask[doneAuctionTask.taskId].doer = doneAuctionTask.doer;
        taskIdToTask[doneAuctionTask.taskId].taskState = TASK_STATE.ASSIGNED;
    }

    /** 
    //Only doer can call receive task after assigned in auction
    //require task state=ASSIGNED
    //require send a commitment token base on their creditscore
    */
    function receiveTask(
        uint _taskId
    ) external payable checkTaskState(TASK_STATE.ASSIGNED, _taskId) {
        require(msg.sender == taskIdToTask[_taskId].doer, "Only doer can call");
        require(taskIdToTask[_taskId].taskId == _taskId, "taskID not found");
        uint commitmentToken = creditScore.calculateCommitmentToken(msg.sender);
        require(
            msg.value >= commitmentToken,
            "Not provide enough money to receive task!"
        );
        taskIdToTask[_taskId].taskState = TASK_STATE.RECEIVED;
        taskIdToTask[_taskId].timeDoerReceive = block.timestamp;
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
        uint payReward = (taskIdToTask[_taskId].reward * percentageDone) / 100; //in wei or decimal 10^18

        //transfer reward and commitmentToken deposit before
        payable(taskIdToTask[_taskId].doer).transfer(payReward);

        //update taskDone history to CreditScore for future calculation
        creditScore.saveTaskDone(
            _taskId,
            taskIdToTask[_taskId].doer,
            percentageDone
        );
        taskIdToTask[_taskId].taskState = TASK_STATE.REVIEWED;
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
