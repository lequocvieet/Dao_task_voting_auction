pragma solidity ^0.8.17;

import "./interfaces/ITaskManager.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBatchTaskVoting.sol";
import "hardhat/console.sol";

contract BatchTaskVoting is IBatchTaskVoting, Ownable {
    ITaskManager public taskManager;

    //mapping batchTaskIdToBatchTaskVoting
    mapping(uint => BatchTaskVoting) batchTaskIdToBatchTaskVoting;

    mapping(uint => PollVoting) pollIdToPoll;

    PollVoting[] public pollVotings;

    mapping(uint => mapping(address => bool)) pollIdToVoterToVoted;

    mapping(uint => mapping(address => uint)) pollIdToVoterToPreviousVote;

    mapping(uint => mapping(uint => int256)) batchTaskIdToPollIdToPreviousResult;

    //Array to store all BatchTaskVoting on vote and voted
    BatchTaskVoting[] public batchTasks;

    event OpenForVote(
        uint indexed _pollId,
        uint[] _batchTaskID,
        uint _voteDuration,
        POLL_STATE _pollState,
        uint timeStart
    );

    event VoteOnBatchTask(
        uint indexed _pollId,
        BatchTaskVoting batchTaskVoted,
        uint voteTime,
        address indexed voter
    );

    event Notify(string notify);

    event EndVote(
        uint indexed pollId,
        POLL_STATE pollState,
        BatchTaskVoting batchTaskCanEnd,
        uint endTime
    );

    event InitBatchTaskAuction(
        uint indexed pollId,
        POLL_STATE pollState,
        BatchTaskVoting batchTaskAuction,
        uint time
    );

    modifier checkPollState(POLL_STATE requiredState, uint _pollID) {
        require(
            pollIdToPoll[_pollID].pollState == requiredState,
            "Error: Invalid Poll state!"
        );
        _;
    }

    function setTaskManager(address _taskManagerAddress) external onlyOwner {
        taskManager = ITaskManager(_taskManagerAddress);
    }

    //OnlyCall by TaskManager to open for vote
    function openPollForVote(
        uint _pollId,
        uint _voteDuration,
        uint[] memory _batchTaskids
    ) external {
        require(msg.sender == address(taskManager), "Only call by TaskManager");
        PollVoting memory newPoll = PollVoting({
            pollId: _pollId,
            voteDuration: _voteDuration,
            startTime: block.timestamp,
            batchTaskIds: _batchTaskids,
            pollState: POLL_STATE.OPENFORVOTE
        });
        pollIdToPoll[_pollId] = newPoll;
        pollVotings.push(newPoll);
        for (uint i = 0; i < _batchTaskids.length; i++) {
            address[] memory _voters;
            BatchTaskVoting memory newBatchTask = BatchTaskVoting({
                batchTaskId: _batchTaskids[i],
                result: 0, // initialize result=0
                voters: _voters
            });
            batchTaskIdToBatchTaskVoting[_batchTaskids[i]] = newBatchTask;
            batchTasks.push(newBatchTask);
        }
        emit OpenForVote(
            _pollId,
            _batchTaskids,
            _voteDuration,
            POLL_STATE.OPENFORVOTE,
            block.timestamp
        );
    }

    /**
     *User call this function to vote on batchTask
     *Require Poll state=OPENFORVOTE
     *require time.vote > timeOpenForVote
     *Each user can vote many times
     */
    function voteOnBatchTask(
        uint _batchTaskID,
        uint _pollId
    ) public checkPollState(POLL_STATE.OPENFORVOTE, _pollId) {
        require(
            block.timestamp >= pollIdToPoll[_pollId].startTime &&
                block.timestamp <=
                pollIdToPoll[_pollId].startTime +
                    pollIdToPoll[_pollId].voteDuration,
            "Poll Voting is end"
        );

        if (pollIdToVoterToVoted[_pollId][msg.sender] == true) {
            //Vote again
            require(
                pollIdToVoterToPreviousVote[_pollId][msg.sender] !=
                    _batchTaskID,
                "You not change your vote"
            );
            for (
                uint i = 0;
                i < pollIdToPoll[_pollId].batchTaskIds.length;
                i++
            ) {
                //revert previous result
                batchTaskIdToBatchTaskVoting[
                    pollIdToPoll[_pollId].batchTaskIds[i]
                ].result = batchTaskIdToPollIdToPreviousResult[
                    pollIdToPoll[_pollId].batchTaskIds[i]
                ][_pollId];
            }
        }

        for (uint j = 0; j < pollIdToPoll[_pollId].batchTaskIds.length; j++) {
            if (pollIdToVoterToVoted[_pollId][msg.sender] != true) {
                batchTaskIdToBatchTaskVoting[
                    pollIdToPoll[_pollId].batchTaskIds[j]
                ].voters.push(msg.sender);
            }
            batchTaskIdToPollIdToPreviousResult[
                pollIdToPoll[_pollId].batchTaskIds[j]
            ][_pollId] = batchTaskIdToBatchTaskVoting[
                pollIdToPoll[_pollId].batchTaskIds[j]
            ].result;

            if (
                batchTaskIdToBatchTaskVoting[
                    pollIdToPoll[_pollId].batchTaskIds[j]
                ].batchTaskId != _batchTaskID
            ) {
                //Vote no for others batch in poll
                batchTaskIdToBatchTaskVoting[
                    pollIdToPoll[_pollId].batchTaskIds[j]
                ].result--;
            } else {
                //vote yes
                batchTaskIdToBatchTaskVoting[
                    pollIdToPoll[_pollId].batchTaskIds[j]
                ].result++;
            }
        }
        pollIdToVoterToPreviousVote[_pollId][msg.sender] = _batchTaskID;
        pollIdToVoterToVoted[_pollId][msg.sender] = true;
        emit VoteOnBatchTask(
            _pollId,
            batchTaskIdToBatchTaskVoting[_batchTaskID],
            block.timestamp,
            msg.sender
        );
    }

    /**
     *ToDo:only call by keeper()
     *Only batchTask with State=OPENFORVOTE and is due(endVote time > start vote+duration)
     */
    function endVote() external {
        bool found = false;
        for (uint i = 0; i < pollVotings.length; i++) {
            if (
                pollVotings[i].pollState == POLL_STATE.OPENFORVOTE &&
                ((pollVotings[i].startTime + pollVotings[i].voteDuration) <
                    block.timestamp)
            ) {
                found = true;
                pollVotings[i].pollState = POLL_STATE.VOTED;
                int256 max = batchTaskIdToBatchTaskVoting[
                    pollVotings[i].batchTaskIds[0]
                ].result;
                for (uint j = 0; j < pollVotings[i].batchTaskIds.length; j++) {
                    if (
                        batchTaskIdToBatchTaskVoting[
                            pollVotings[i].batchTaskIds[j]
                        ].result > max
                    ) {
                        max = batchTaskIdToBatchTaskVoting[
                            pollVotings[i].batchTaskIds[j]
                        ].result;
                    }
                    emit EndVote(
                        pollVotings[i].pollId,
                        POLL_STATE.VOTED,
                        batchTaskIdToBatchTaskVoting[
                            pollVotings[i].batchTaskIds[j]
                        ],
                        block.timestamp
                    );
                }
                //Choose batchTask with higher results
                for (uint k = 0; k < pollVotings[i].batchTaskIds.length; k++) {
                    if (
                        max ==
                        batchTaskIdToBatchTaskVoting[
                            pollVotings[i].batchTaskIds[k]
                        ].result
                    ) {
                        //Call to taskManager
                        taskManager.initBatchTaskAuction(
                            pollVotings[i].batchTaskIds[k]
                        );
                        emit InitBatchTaskAuction(
                            pollVotings[i].pollId,
                            POLL_STATE.VOTED,
                            batchTaskIdToBatchTaskVoting[
                                pollVotings[i].batchTaskIds[k]
                            ],
                            block.timestamp
                        );
                        break;
                    }
                }
            }
        }
        if (found == false) {
            emit Notify("There are no Poll Voting can end at the moment");
        }
    }

    function getAllPollVoting() public view returns (PollVoting[] memory) {
        PollVoting[] memory polls = new PollVoting[](pollVotings.length);
        for (uint i = 0; i < pollVotings.length; i++) {
            polls[i] = pollIdToPoll[i + 1];
        }
        return polls;
    }

    function getAllBatchTaskVoting(
        uint _pollID
    ) public view returns (BatchTaskVoting[] memory) {
        BatchTaskVoting[] memory listBatchTasks = new BatchTaskVoting[](
            pollIdToPoll[_pollID].batchTaskIds.length
        );
        for (uint i = 0; i < pollIdToPoll[_pollID].batchTaskIds.length; i++) {
            listBatchTasks[i] = batchTaskIdToBatchTaskVoting[
                pollIdToPoll[_pollID].batchTaskIds[i]
            ];
        }
        return listBatchTasks;
    }
}
