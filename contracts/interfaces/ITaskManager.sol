pragma solidity ^0.8.17;
import "./ITaskAuction.sol";

interface ITaskManager {
    struct Task {
        uint taskId;
        uint point; //point is caculated by durations 1 point=4 hour
        uint reward;
        uint minReward;
        address reporter;
        address doer;
        address reviewer;
        uint timeDoerReceive;
        TASK_STATE taskState;
    }

    struct Poll {
        uint pollId;
        address pollOwner;
        uint[] batchTaskIds;
        POLL_STATE pollState;
    }

    enum POLL_STATE {
        CREATED,
        OPENFORVOTE,
        VOTED
    }

    struct BatchTask {
        uint batchTaskId;
        uint[] taskIds;
        BATCH_TASK_STATE batchTaskState;
    }

    enum BATCH_TASK_STATE {
        CREATED,
        VOTED,
        OPENFORAUCTION
    }

    enum TASK_STATE {
        CREATED,
        ASSIGNED,
        RECEIVED,
        SUBMITTED,
        REVIEWED
    }

    function initPoll(address _pollOwner) external;

    function initBatchTask(uint _pollId) external;

    function initTask(
        uint _batchTaskId,
        uint _point, //point is caculated by durations 1 point=4 hour
        uint _reward,
        uint _minReward,
        address _reporter,
        address _reviewer
    ) external;

    function openPollForVote(uint _pollId, uint _voteDuration) external;

    function initBatchTaskAuction(uint _batchTaskId) external;

    function openBatchTaskForAuction(
        uint _batchTaskID,
        uint _auctionDuration
    ) external;

    function assignTask(
        ITaskAuction.AuctionTask memory doneAuctionTask
    ) external;

    function receiveTask(uint _taskId, uint _commitValue) external;

    function submitTaskResult(uint _taskId) external;

    function submitReview(
        uint _taskId,
        uint percentageDone //ex:100==100%
    ) external;

    function updateTask(
        uint _taskId,
        uint _newPoint //point =duration
    ) external;

    function getAllBatchTaskByPollID(
        uint _pollID
    ) external view returns (BatchTask[] memory);

    function getAllPoll() external view returns (Poll[] memory);
}
