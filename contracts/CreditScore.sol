// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "./interfaces/ICreditScore.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";

contract CreditScore is ICreditScore {
    CreditScore[] creditScores;
    mapping(address => User) public userAddressToUser;

    mapping(uint => TaskDone) public taskDoneIdTaskDone;

    User[] users;

    event SaveTaskDone(
        uint taskId,
        address indexed doer,
        uint percentageDone,
        uint timeSave
    );

    event CalculateCommitmentToken(address indexed user, uint value);

    //Todo:only call internal of this contract
    //Todo: exponential case
    function calculateScoreByPercentTaskDone(
        address _userAddress
    ) public override returns (uint) {
        //iterate through all taskDone
        if (userAddressToUser[_userAddress].userAddress == address(0)) {
            //no data before
            return 50; //initialize value score
        }
        for (
            uint i = 0;
            i < userAddressToUser[_userAddress].taskDoneIds.length;
            i++
        ) {
            if (
                taskDoneIdTaskDone[
                    userAddressToUser[_userAddress].taskDoneIds[i]
                ].percentageDone > 60
            ) {
                //If percentage of each taskDone>=60% increase score by 1
                userAddressToUser[_userAddress].score += 1;
            } else if (
                taskDoneIdTaskDone[
                    userAddressToUser[_userAddress].taskDoneIds[i]
                ].percentageDone < 30
            ) {
                //Else 30%-60% do nothing to score
            } else {
                //Else minus 1
                userAddressToUser[_userAddress].score =
                    userAddressToUser[_userAddress].score -
                    1;
            }
            return userAddressToUser[_userAddress].score;
        }
    }

    //Todo:only call by taskManager
    function saveTaskDone(
        uint _taskId,
        address _doer,
        uint _percentageDone
    ) public {
        if (userAddressToUser[_doer].userAddress == address(0)) {
            //no history before
            User memory user;
            uint[] memory taskDoneIds = new uint[](10000);
            taskDoneIds[0] = _taskId;
            user.userAddress = _doer;
            user.score = 50; //initialize 50
            user.taskDoneIds = taskDoneIds;
            taskDoneIdTaskDone[_taskId].percentageDone = _percentageDone;
            userAddressToUser[_doer] = user;
        } else {
            userAddressToUser[_doer].taskDoneIds.push(_taskId);
        }
        emit SaveTaskDone(_taskId, _doer, _percentageDone, block.timestamp);
    }

    //Calculate commitment token based on credit score
    function calculateCommitmentToken(address _user) public returns (uint) {
        //getCreditScore of user
        uint userScore = calculateScoreByPercentTaskDone(_user);
        uint commitmentToken = userScore * 2; //this rule can change in the future
        console.log(commitmentToken);
        emit CalculateCommitmentToken(_user, commitmentToken);
        return commitmentToken;
    }
}
