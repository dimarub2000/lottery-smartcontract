// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";

contract Lottery is VRFConsumerBase, KeeperCompatibleInterface, Ownable {
    address payable[] public players;
    address payable public recentWinner;

    address public vrfCoordinator = 0xa555fC018435bef5A13C6c6870a9d4C11DEC329C;
    address public link = 0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06;

    bytes32 public keyHash = 0xcaf3c3727e033261d383b315559476f48034c13b18f8cafed4d871abe5049186;
    uint256 public fee = 0.1 * 10 ** 18;

    event RequestedRandomness(bytes32 requestId);
    event newPlayer(address player);
    event PaidWinner(address from, address winner);

    uint public immutable interval;
    uint public lastTimeStamp;

    enum LOTTERY_STATE {
        OPEN,
        CLOSED,
        CALCULATING_WINNER
    }
    LOTTERY_STATE public lotteryState;

    constructor(uint updateInterval) VRFConsumerBase(vrfCoordinator, link) {
        interval = updateInterval;
        lotteryState = LOTTERY_STATE.CLOSED;
    }

    function enterLottery() public payable {
        require(lotteryState == LOTTERY_STATE.OPEN, "Lottery hasn't been started yet!");
        players.push(payable(msg.sender));
        emit newPlayer(msg.sender);
    }

    function startLottery() public onlyOwner {
        require(lotteryState == LOTTERY_STATE.CLOSED, "Can't start a new lottery yet!");
        lastTimeStamp = block.timestamp;
        lotteryState = LOTTERY_STATE.OPEN;
    }

    function endLotteryInternal() internal {
        lotteryState = LOTTERY_STATE.CALCULATING_WINNER;
        if (players.length > 0) {
            bytes32 requestId = requestRandomness(keyHash, fee);
            emit RequestedRandomness(requestId);
        } else {
            lotteryState = LOTTERY_STATE.CLOSED;
        }
    }

    function endLottery() public onlyOwner {
        endLotteryInternal();
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        require(lotteryState == LOTTERY_STATE.CALCULATING_WINNER, "You aren't there yet!");
        require(randomness > 0, "random-not-found");

        uint256 indexOfWinner = randomness % players.length;
        recentWinner = players[indexOfWinner];
        recentWinner.transfer(address(this).balance);
        emit PaidWinner(address(this), recentWinner);

        players = new address payable[](0);
        lotteryState = LOTTERY_STATE.CLOSED;
    }

    function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory /* performData */) {
        upkeepNeeded = lotteryState == LOTTERY_STATE.OPEN && (block.timestamp - lastTimeStamp) > interval;
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        if (lotteryState == LOTTERY_STATE.OPEN && (block.timestamp - lastTimeStamp) > interval) {
            endLotteryInternal();
        }
    }
}
