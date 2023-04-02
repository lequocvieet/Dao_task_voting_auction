// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;
import "./ITaskManager.sol";

interface IBatchTaskVoting {
    struct BatchTaskVoting {
        uint batchTaskId;
        int256 result; //Initialize=0,Yes+1
        address[] voters; //list voter
    }
    enum POLL_STATE {
        OPENFORVOTE,
        VOTED
    }

    struct PollVoting {
        uint pollId;
        uint voteDuration; //seconds
        uint startTime;
        uint[] batchTaskIds;
        POLL_STATE pollState;
    }

    function setTaskManager(address _taskManagerAddress) external;

    function voteOnBatchTask(uint _batchTaskID, uint _pollId) external;

    function endVote() external;

    function openPollForVote(
        uint _pollId,
        uint _voteDuration,
        uint[] memory _batchTaskids
    ) external;
}
