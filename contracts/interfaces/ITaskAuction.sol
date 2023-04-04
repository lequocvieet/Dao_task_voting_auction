// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;
import "./ITaskManager.sol";

interface ITaskAuction {
    struct AuctionTask {
        uint taskId;
        uint point; // 1 point=4 hour doing Task
        uint reward;
        uint minReward;
        address reporter;
        address doer;
        address reviewer;
        TASK_STATE taskState;
        uint lowestBidAmount;
        address lowestBidder;
    }

    struct BatchTaskAuction {
        uint pollId;
        uint batchTaskId;
        uint[] taskIds;
        uint duration;
        uint startTime;
        BATCH_TASK_STATE batchTaskState;
    }

    enum BATCH_TASK_STATE {
        OPENFORAUCTION,
        ENDAUCTION
    }

    enum TASK_STATE {
        OPENFORAUCTION,
        ASSIGNED,
        RECEIVED,
        SUBMITTED,
        REVIEWED
    }

    struct Bid {
        //represent user bid on specific task
        address payable bidder;
        uint taskId;
        uint totalBidAmount;
        uint numberBid; //number place Bid
    }

    function setTaskManager(address _taskManagerAddress) external;

    function chooseToken(address _tokenAddress) external;

    function setBankManager(address _bankManagerAddress) external;

    function openTaskForAuction(
        uint _pollId,
        ITaskManager.Task[] memory _tasks,
        uint _batchTaskId,
        uint _auctionDuration
    ) external;

    function placeBid(
        uint _taskID,
        uint _batchTaskID,
        uint _amountBid
    ) external;

    function endAuction() external;

    function placeMultipleBid(
        uint[] memory taskIds,
        uint _batchTaskID,
        uint[] memory _amountBids
    ) external;
}
