// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";

contract Lottery is VRFConsumerBase, KeeperCompatibleInterface, Ownable {
    address payable[] public players;
    uint256[] public balances;
    uint256 public totalBalance = 0;
    address payable public recentWinner;

    event RequestedRandomness(bytes32 requestId);
    event newPlayer(address player);
    event PaidWinner(address from, address winner);
    event LotteryStarted(uint256 duration);
    event LotteryFinished();

    uint256 public lotteryDuration;
    uint256 public lastTimeStamp;
    uint256 public fee;
    bytes32 public keyHash;

    uint256 public randomBalancePoint;
    uint256 public accumulatedBalance;
    uint256 public indexOfWinner;

    enum LOTTERY_STATE {
        OPEN,
        CLOSED,
        CALCULATING_WINNER
    }
    LOTTERY_STATE public lotteryState;

    constructor(
        address _vrfCoordinator,
        address _link,
        uint256 _fee,
        bytes32 _keyHash
     ) VRFConsumerBase(_vrfCoordinator, _link) {
        fee = _fee;
        keyHash = _keyHash;
        lotteryState = LOTTERY_STATE.CLOSED;
    }

    function enterLottery() public payable {
        require(lotteryState == LOTTERY_STATE.OPEN, "Lottery hasn't been started yet!");
        balances.push(msg.value);
        totalBalance += msg.value;
        players.push(payable(msg.sender));
        emit newPlayer(msg.sender);
    }

    function startLottery(uint256 duration) public onlyOwner {
        require(lotteryState == LOTTERY_STATE.CLOSED, "Can't start a new lottery yet!");
        lotteryDuration = duration;
        lastTimeStamp = block.timestamp;
        lotteryState = LOTTERY_STATE.OPEN;
        emit LotteryStarted(lotteryDuration);
    }

    function endLotteryInternal() internal {
        lotteryState = LOTTERY_STATE.CALCULATING_WINNER;
        if (players.length > 0) {
            bytes32 requestId = requestRandomness(keyHash, fee);
            emit RequestedRandomness(requestId);
        } else {
            lotteryState = LOTTERY_STATE.CLOSED;
            emit LotteryFinished();
        }
    }

    function endLottery() public onlyOwner {
        endLotteryInternal();
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        require(lotteryState == LOTTERY_STATE.CALCULATING_WINNER, "You aren't there yet!");
        require(randomness > 0, "random-not-found");

        randomBalancePoint = randomness % totalBalance;
        accumulatedBalance = 0;
        indexOfWinner = 0;

        for (uint i = 0; i < balances.length; i++) {
            accumulatedBalance += balances[i];
            if (accumulatedBalance >= randomBalancePoint) {
                indexOfWinner = i;
                break;
            }
        }

        recentWinner = players[indexOfWinner];
        recentWinner.transfer(address(this).balance);
        emit PaidWinner(address(this), recentWinner);

        players = new address payable[](0);
        balances = new uint256[](0);
        totalBalance = 0;
        lotteryState = LOTTERY_STATE.CLOSED;
        emit LotteryFinished();
    }

    function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory /* performData */) {
        upkeepNeeded = lotteryState == LOTTERY_STATE.OPEN && (block.timestamp - lastTimeStamp) > lotteryDuration;
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        if (lotteryState == LOTTERY_STATE.OPEN && (block.timestamp - lastTimeStamp) > lotteryDuration) {
            endLotteryInternal();
        }
    }
}
