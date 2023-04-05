pragma solidity ^0.8.17;
import "./interfaces/ITaskManager.sol";
import "./interfaces/ITaskAuction.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBankManager.sol";
import "hardhat/console.sol";

//Todo: ver2: instead of using for loop =>use more mapping
contract TaskAuction is ITaskAuction, Ownable {
    ITaskManager public taskManager;

    IBankManager public bankManager;

    // Array to store all the tasks on Auction
    AuctionTask[] public auctionTasks;

    address public tokenAddress;

    Bid[] public bids;

    BatchTaskAuction[] public batchTaskAuctions;

    //mapping  TaskId To AuctionTask
    mapping(uint => AuctionTask) public taskIdToAuctionTask;
    mapping(uint => BatchTaskAuction) public batchTaskIdToBatchTask;

    event OpenTaskForAuction(
        uint indexed _batchTaskId,
        uint _auctionDuration,
        AuctionTask auctionTask,
        BATCH_TASK_STATE batchTaskState,
        uint timeStart
    );

    event PlaceBid(
        uint indexed _taskID,
        uint indexed _batchTaskID,
        AuctionTask auctionTask,
        Bid bid,
        uint bidTime
    );

    event Notify(string notify);

    event AssignTask(
        uint indexed batchTaskId,
        AuctionTask taskAssigned,
        uint assignTime
    );

    event EndAuction(
        uint indexed batchTaskId,
        BATCH_TASK_STATE batchTaskState,
        AuctionTask assignedTask,
        uint endTime
    );

    modifier checkTaskState(TASK_STATE requiredState, uint _taskID) {
        require(
            taskIdToAuctionTask[_taskID].taskState == requiredState,
            "Error: Invalid Task State"
        );
        _;
    }

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

    function setTaskManager(address _taskManagerAddress) external onlyOwner {
        taskManager = ITaskManager(_taskManagerAddress);
    }

    function chooseToken(address _tokenAddress) external onlyOwner {
        tokenAddress = _tokenAddress;
    }

    function setBankManager(address _bankManagerAddress) external onlyOwner {
        bankManager = IBankManager(_bankManagerAddress);
    }

    //only call by taskManager
    function openTaskForAuction(
        uint _pollId,
        ITaskManager.Task[] memory _tasks,
        uint _batchTaskId,
        uint _auctionDuration
    ) public {
        require(msg.sender == address(taskManager), "Only call by TaskManager");
        uint[] memory _taskIds = new uint[](_tasks.length);
        for (uint i = 0; i < _tasks.length; i++) {
            address payable _lowestBidder;
            AuctionTask memory newAuctionTask = AuctionTask({
                taskId: _tasks[i].taskId,
                point: _tasks[i].point, // 1 point=4 hour doing Task
                reward: _tasks[i].reward,
                minReward: _tasks[i].minReward,
                reporter: _tasks[i].reporter,
                doer: address(0),
                reviewer: _tasks[i].reviewer,
                taskState: TASK_STATE.OPENFORAUCTION,
                lowestBidAmount: _tasks[i].reward,
                lowestBidder: _lowestBidder
            });
            //save to mapping
            taskIdToAuctionTask[_tasks[i].taskId] = newAuctionTask;
            //save to array
            auctionTasks.push(newAuctionTask);
            _taskIds[i] = _tasks[i].taskId;
            emit OpenTaskForAuction(
                _batchTaskId,
                _auctionDuration,
                newAuctionTask,
                BATCH_TASK_STATE.OPENFORAUCTION,
                block.timestamp
            );
        }
        BatchTaskAuction memory newBatchTaskAuction = BatchTaskAuction({
            pollId: _pollId,
            batchTaskId: _batchTaskId,
            taskIds: _taskIds,
            duration: _auctionDuration,
            startTime: block.timestamp,
            batchTaskState: BATCH_TASK_STATE.OPENFORAUCTION
        });
        batchTaskAuctions.push(newBatchTaskAuction);
        batchTaskIdToBatchTask[_batchTaskId] = newBatchTaskAuction;
    }

    /** 
    //Anyone can call to placeBid many times
    //Once Bid require amount money>= minReward and < lowestBidAmount
    //Require taskState=OPENFORAUCTION
    //Require time placeBid < time startAuction+duration
    //Todo: case use bid against their previous bid
    */
    function placeBid(
        uint _taskID,
        uint _batchTaskID,
        uint _amountBid
    )
        public
        checkBatchTaskState(BATCH_TASK_STATE.OPENFORAUCTION, _batchTaskID)
    {
        AuctionTask storage auctionTask = taskIdToAuctionTask[_taskID];
        require(auctionTask.taskId == _taskID, "Wrong taskID");
        //Todo: if value bid ==minreward end auction
        require(
            bankManager.balanceOf(msg.sender, tokenAddress) >= _amountBid,
            "Your balance not enough"
        );
        require(
            _amountBid >= auctionTask.minReward &&
                _amountBid < auctionTask.lowestBidAmount,
            "Insufficient bid amount "
        );
        bankManager.transfer(
            msg.sender,
            tokenAddress,
            address(bankManager),
            _amountBid
        );
        Bid memory bid = _findBid(_taskID, msg.sender);
        if (bid.bidder == address(0)) {
            bid.bidder = payable(msg.sender);
            bid.taskId = _taskID;
        }
        //increase value bid each time call
        bid.totalBidAmount += _amountBid;
        //increase number bid
        bid.numberBid++;

        // If current bid is lower than current lowest bid, update lowestBidAmount and lowestBidder
        if (_amountBid < auctionTask.lowestBidAmount) {
            auctionTask.lowestBidAmount = _amountBid;
            auctionTask.lowestBidder = msg.sender;
        }
        //update value in mapping
        taskIdToAuctionTask[_taskID] = auctionTask;

        //update in array
        for (uint i = 0; i < auctionTasks.length; i++) {
            if (auctionTasks[i].taskId == _taskID) {
                auctionTasks[i] = auctionTask;
                break;
            }
        }
        //save bid to bids
        bids.push(bid);
        emit PlaceBid(_taskID, _batchTaskID, auctionTask, bid, block.timestamp);
    }

    function placeMultipleBid(
        uint[] memory taskIds,
        uint _batchTaskID,
        uint[] memory _amountBids
    ) public {
        for (uint i = 0; i < taskIds.length; i++) {
            placeBid(taskIds[i], _batchTaskID, _amountBids[i]);
        }
    }

    //Todo: only call by keeper(cronjob)
    //getAll batchTask with state=OPENFORAUCTION
    //and time Start+duration> time callEndAuction
    function endAuction() public {
        bool found = false;
        for (uint i = 0; i < batchTaskAuctions.length; i++) {
            if (
                batchTaskAuctions[i].batchTaskState ==
                BATCH_TASK_STATE.OPENFORAUCTION &&
                (block.timestamp >
                    batchTaskAuctions[i].startTime +
                        batchTaskAuctions[i].duration)
            ) {
                found = true;
                for (uint j = 0; j < batchTaskAuctions[i].taskIds.length; j++) {
                    //check auction Task had user bided
                    if (
                        taskIdToAuctionTask[batchTaskAuctions[i].taskIds[j]]
                            .lowestBidder != address(0)
                    ) {
                        // Assign task to lowest bidder
                        taskIdToAuctionTask[batchTaskAuctions[i].taskIds[j]]
                            .reward = taskIdToAuctionTask[
                            batchTaskAuctions[i].taskIds[j]
                        ].lowestBidAmount;
                        taskIdToAuctionTask[batchTaskAuctions[i].taskIds[j]]
                            .doer = taskIdToAuctionTask[
                            batchTaskAuctions[i].taskIds[j]
                        ].lowestBidder;
                        taskIdToAuctionTask[batchTaskAuctions[i].taskIds[j]]
                            .taskState = TASK_STATE.ASSIGNED;

                        // Pay all bidders back their bids
                        for (uint k = 0; k < bids.length; k++) {
                            if (
                                bids[k].taskId ==
                                taskIdToAuctionTask[
                                    batchTaskAuctions[i].taskIds[j]
                                ].taskId
                            ) {
                                bankManager.transfer(
                                    address(bankManager),
                                    tokenAddress,
                                    bids[k].bidder,
                                    bids[k].totalBidAmount
                                );
                            }
                        }
                        //call assignTask in Task manager
                        taskManager.assignTask(
                            taskIdToAuctionTask[batchTaskAuctions[i].taskIds[j]]
                        );
                        emit EndAuction(
                            batchTaskAuctions[i].batchTaskId,
                            BATCH_TASK_STATE.ENDAUCTION,
                            taskIdToAuctionTask[
                                batchTaskAuctions[i].taskIds[j]
                            ],
                            block.timestamp
                        );
                    }
                }
            }
        }
        if (found == false) {
            emit Notify("There are no Auction can end at the moment");
        }
    }

    //find bid by taskId and batchTaskId and bidder
    function _findBid(
        uint _taskId,
        address _bidder
    ) internal view returns (Bid memory) {
        for (uint i = 0; i < bids.length; i++) {
            if (bids[i].taskId == _taskId && bids[i].bidder == _bidder) {
                return bids[i];
            } else {
                return
                    Bid({
                        taskId: 0,
                        bidder: payable(address(0)),
                        totalBidAmount: 0,
                        numberBid: 0
                    });
            }
        }
    }

    function getAllBatchTaskAuction(
        uint _pollID
    ) public view returns (BatchTaskAuction[] memory) {
        BatchTaskAuction[] memory listBatchTasks = new BatchTaskAuction[](
            batchTaskAuctions.length
        );
        for (uint i = 0; i < batchTaskAuctions.length; i++) {
            if (batchTaskAuctions[i].pollId == _pollID) {
                listBatchTasks[i] = batchTaskAuctions[i];
            }
        }
        return listBatchTasks;
    }

    function getAllTaskAuction(
        uint _batchTaskId
    ) public view returns (AuctionTask[] memory) {
        AuctionTask[] memory listTasks = new AuctionTask[](
            batchTaskIdToBatchTask[_batchTaskId].taskIds.length
        );
        for (
            uint i = 0;
            i < batchTaskIdToBatchTask[_batchTaskId].taskIds.length;
            i++
        ) {
            listTasks[i] = taskIdToAuctionTask[
                batchTaskIdToBatchTask[_batchTaskId].taskIds[i]
            ];
        }
        return listTasks;
    }
}
