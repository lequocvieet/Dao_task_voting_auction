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

    Bid[] public bids;

    //mapping  TaskId To AuctionTask
    mapping(uint => AuctionTask) taskIdToAuctionTask;

    event OpenTaskForAuction(AuctionTask auctionTask);

    event PlaceBid(Bid bid, uint bidTime, uint bidValue);

    event Notify(string notify);

    event EndAuction(AuctionTask auctionTask, uint endTime);

    modifier checkTaskState(TASK_STATE requiredState, uint _taskID) {
        require(
            taskIdToAuctionTask[_taskID].taskState == requiredState,
            "Error: Invalid Task State"
        );
        _;
    }

    function setTaskManager(address _taskManagerAddress) external onlyOwner {
        taskManager = ITaskManager(_taskManagerAddress);
    }

    //Todo:only call by taskManager
    function openTaskForAuction(
        ITaskManager.Task memory _task,
        uint __auctionDuration
    ) public {
        address payable _lowestBidder;
        AuctionTask memory newAuctionTask = AuctionTask({
            taskId: _task.taskId,
            point: _task.point, // 1 point=4 hour doing Task
            reward: _task.reward,
            minReward: _task.minReward,
            reporter: _task.reporter,
            doer: address(0),
            reviewer: _task.reviewer,
            taskState: TASK_STATE.OPENFORAUCTION,
            lowestBidAmount: _task.reward,
            lowestBidder: _lowestBidder,
            duration: __auctionDuration,
            startTime: block.timestamp
        });
        //save to mapping
        taskIdToAuctionTask[_task.taskId] = newAuctionTask;

        //save to array
        auctionTasks.push(newAuctionTask);
        emit OpenTaskForAuction(newAuctionTask);
    }

    /** 
    //Anyone can call to placeBid many times
    //Once Bid require amount money>= minReward and < lowestBidAmount
    //Require taskState=OPENFORAUCTION
    //Require time placeBid < time startAuction+duration
    */
    function placeBid(
        uint _taskID
    ) public payable checkTaskState(TASK_STATE.OPENFORAUCTION, _taskID) {
        AuctionTask storage auctionTask = taskIdToAuctionTask[_taskID];
        require(auctionTask.taskId == _taskID, "Wrong taskID");
        //Todo: if value bid ==minreward end auction

        //Todo: move check balance to bank manager
        require(
            msg.value >= auctionTask.minReward &&
                msg.value < auctionTask.lowestBidAmount,
            "Insufficient bid amount "
        );
        Bid memory bid = _findBid(_taskID, msg.sender);
        if (bid.bidder == address(0)) {
            bid.bidder = payable(msg.sender);
            bid.taskId = _taskID;
        }
        //increase value bid each time call
        bid.totalBidAmount += msg.value;
        //increase number bid
        bid.numberBid++;

        // If current bid is lower than current lowest bid, update lowestBidAmount and lowestBidder
        if (msg.value < auctionTask.lowestBidAmount) {
            auctionTask.lowestBidAmount = msg.value;
            auctionTask.lowestBidder = msg.sender;
        }
        taskIdToAuctionTask[_taskID] = auctionTask; //update value in mapping

        //auctionTasks.push(auctionTask);
        for (uint i = 0; i < auctionTasks.length; i++) {
            if (auctionTasks[i].taskId == _taskID) {
                auctionTasks[i] = auctionTask;
                break;
            }
        }
        //save bid to bids
        bids.push(bid);
        emit PlaceBid(bid, block.timestamp, msg.value);
    }

    function placeMultipleBid(uint[] memory taskIds) public {
        for (uint i = 0; i < taskIds.length; i++) {
            placeBid(taskIds[i]);
        }
    }

    //Todo: only call by keeper
    function endAuction() public {
        //getAll batchTask with state=OPENFORAUCTION
        //and time Start+duration> time callEndAuction
        bool found = false;
        for (uint i = 0; i < auctionTasks.length; i++) {
            if (
                auctionTasks[i].taskState == TASK_STATE.OPENFORAUCTION &&
                (block.timestamp >
                    auctionTasks[i].startTime + auctionTasks[i].duration)
            ) {
                found = true;
                //check auction Task had user bided
                if (auctionTasks[i].lowestBidder != address(0)) {
                    // Assign task to lowest bidder
                    auctionTasks[i].reward = auctionTasks[i].lowestBidAmount;
                    auctionTasks[i].doer = auctionTasks[i].lowestBidder;
                    auctionTasks[i].taskState = TASK_STATE.ASSIGNED;

                    emit EndAuction(auctionTasks[i], block.timestamp);
                    // Pay all bidders back their bids
                    for (uint j = 0; j < bids.length; j++) {
                        if (bids[j].taskId == auctionTasks[j].taskId) {
                            payable(bids[j].bidder).transfer(
                                bids[j].totalBidAmount
                            );
                        }
                    }
                    //call assignTask in Task manager
                    taskManager.assignTask(auctionTasks[i]);
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
}
