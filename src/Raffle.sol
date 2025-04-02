// Layout of the contract file:
// version
// imports
// errors
// interfaces, libraries, contract

// Inside Contract:
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private

// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
/**
 * @title A better Raffle Contract
 * @author Suraj
 * @notice The contract is to creating a simple raffle
 * @dev It impliments ChainlinkVRF v2.5 and Chainlik Automation
 */

import {VRFConsumerBaseV2Plus} from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract Raffle is VRFConsumerBaseV2Plus {
    // Type Declaration

    enum RaffleState {
        OPEN, //0
        CALCULATING //1

    }

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint16 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callBackGasLimit;
    address payable[] s_players;
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;
    address payable private recentWinner;
    RaffleState private s_raffleState;
    // Events

    event EnteredRaffle(address indexed player);
    event PickedWinner(address winner);

    // Constructor
    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callBackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callBackGasLimit = callBackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    // Errors

    error Raffle_notEnoughETHSent();
    error Raffle_TransferFailed();
    error Raffle_CalculatingWinner();
    error Raffle_RaffleNotOpened();
    error Raffle__UpKeepNotNeeded(uint256 balance, uint256 length, uint256 raffleState);
    // Modifiers

    // Functions
    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) revert Raffle_notEnoughETHSent();
        if (s_raffleState != RaffleState.OPEN) revert Raffle_RaffleNotOpened();
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    /**
     * @dev This is the function that Chainlink nodes will call to see
     * if the lottery is ready to pick the winner
     * The following should be true in order to pickup the winner
     * 1. The time interval has passed between raffle runs
     * 2. Contract has Balance
     * 3. Lottery is Open
     * 4. Lottery has Players
     * 5. Implicitly, You subscription has LINK
     */
    function checkUpKeep(bytes memory /*checkData*/ )
        public
        view
        returns (bool upKeepNeeded, bytes memory /*performData*/ )
    {
        bool timePassed = (block.timestamp - s_lastTimeStamp >= i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upKeepNeeded = timePassed && isOpen && hasBalance && hasPlayers;
        return (upKeepNeeded, hex"");
    }

    function performUpKeep(bytes calldata /*performData*/ ) external {
        (bool upKeepNeeded,) = checkUpKeep("");
        if (!upKeepNeeded) {
            revert Raffle__UpKeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callBackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
            )
        });

        s_vrfCoordinator.requestRandomWords(request);
    }

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function fulfillRandomWords(uint256, /*requestId*/ uint256[] calldata randomWords) internal override {
        uint256 indexOfRecentWinner = randomWords[0] % s_players.length;
        recentWinner = s_players[indexOfRecentWinner];
        (bool success,) = recentWinner.call{value: address(this).balance}("");

        if (!success) {
            revert Raffle_TransferFailed();
        }
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit PickedWinner(recentWinner);
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayerAtIndex(uint256 index) external view returns (address player) {
        return s_players[index];
    }

    function getTotalPlayers() external view returns (uint256) {
        return s_players.length;
    }

    function changeRaffleState() public {
        s_raffleState = RaffleState.CALCULATING;
    }
}
