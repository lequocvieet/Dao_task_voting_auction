pragma solidity ^0.8.17;

interface ICreditScore {
    struct TaskDone {
        uint taskId;
        uint percentageDone;
    }

    struct User {
        address userAddress;
        uint score; //credit score
        uint[] taskDoneIds;
    }

    function saveTaskDone(
        uint _taskId,
        address _doer,
        uint _percentageDone
    ) external;

    function calculateCommitmentToken(address _user) external returns (uint);
}
