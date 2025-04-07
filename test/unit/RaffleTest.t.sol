// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig, GetChainIds} from "script/HelperConfig.s.sol";
import {Raffle} from "src/Raffle.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from
    "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is GetChainIds, Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    event EnteredRaffle(address indexed player);
    event PickedWinner(address winner);

    address public PLAYER = makeAddr("Player");
    uint256 public constant PLAYER_INITIAL_BALANCE = 20 ether;
    uint160 public constant INITIAL_ENTRANCE_FEE = 0.25 ether;
    uint160 public constant GAS_PRICE = 20000;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callBackGasLimit;
    address link;
    uint256 length;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployRaffleContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        //vm.deal giving player initial balance which is required for transactions;
        vm.deal(PLAYER, PLAYER_INITIAL_BALANCE);
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callBackGasLimit = config.callBackGasLimit;
        link = config.link;

        //getting length of the Players to not reading this everytime from storage (gas optimization)
        length = raffle.getTotalPlayers();
    }

    function testInitialRaffleState() public view {
        // console.log(config.vrfCoordinator);
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testEnterRaffleEvent() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(address(PLAYER));

        raffle.enterRaffle{value: INITIAL_ENTRANCE_FEE}();
    }

    function testraffleRevertsWhenYouDontPayEnoughETH() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle_notEnoughETHSent.selector);
        raffle.enterRaffle{value: 0.1 ether}();
    }

    function testRaffleEnterWhenPayingEnoughEntranceFee() public funder {
        // send tx with a specific gas using vm.txGasPrice();
        // vm.txGasPrice(GAS_PRICE);
        raffle.enterRaffle{value: INITIAL_ENTRANCE_FEE}();
        assert(raffle.getPlayerAtIndex(0) == address(PLAYER));
        // console.log(tx.gasprice);
    }

    function testEntraceFee() public {
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        assertEq(raffle.getEntranceFee(), config.entranceFee);
    }

    function testEnterMultiplePlayersAtEnterRaffle() public {
        uint160 totalPlayers = 10;
        for (uint160 i = 1; i < totalPlayers; i++) {
            // hoax will do the both work of vm.prank and vm.deal
            hoax(address(i), PLAYER_INITIAL_BALANCE);
            raffle.enterRaffle{value: INITIAL_ENTRANCE_FEE}();
        }
        assertEq(raffle.getTotalPlayers(), totalPlayers - 1);
        assert(address(raffle).balance == (totalPlayers - 1) * INITIAL_ENTRANCE_FEE);
    }

    function testDontAllowPlayersToEnterRaffleWhileRaffleIsCalculating() public raffleEntered {
        //Arrange
        vm.prank(PLAYER);
        raffle.performUpKeep("");
        // console.log(address(raffle));

        //Act
        vm.expectRevert(Raffle.Raffle_RaffleNotOpened.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: INITIAL_ENTRANCE_FEE}();

        //Assert
    }

    function testCheckUpKeepReturnsFalseIfItHasNoBalance() public {
        //Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        //Act
        (bool check,) = raffle.checkUpKeep("");
        //Assert
        assert(!check);
    }

    function testCheckUpKeepReturnsFalseIfRaffleStateIsNotOpened() public funder raffleEntered {
        //Arrange
        raffle.performUpKeep("");
        //Act
        (bool upKeepNeeded,) = raffle.checkUpKeep("");
        //Assert
        assert(!upKeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfNotEnoughTimeHasPassed() public funder {
        //Arrang
        raffle.enterRaffle{value: INITIAL_ENTRANCE_FEE}();

        //Act
        (bool upKeepNeeded,) = raffle.checkUpKeep("");
        //Assert
        assert(!upKeepNeeded);
    }

    function testChangeRaffleStateToBeChanged() public funder {
        //Arrange

        //Act
        raffle.changeRaffleState();
        //Assert
        assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING);
    }

    function testPerformUpKeepToRevertIfUpkeepNeededIsFalse() public funder {
        //Arrange
        uint256 currentBalance;
        uint256 numberOfPlayers;
        raffle.enterRaffle{value: INITIAL_ENTRANCE_FEE}();
        currentBalance = INITIAL_ENTRANCE_FEE;
        numberOfPlayers = 1;
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpKeepNotNeeded.selector, currentBalance, numberOfPlayers, 0)
        );
        // Act
        raffle.performUpKeep("");

        //Assert
    }

    function testCheckPerformUpKeepCanOnlyRunIfUpKeepNeededIsTrue() public raffleEntered {
        //Arrange
        //Act / Assert
        raffle.performUpKeep("");
    }

    function testPerformUpKeepToEmitAndLogTheRequestId() public funder raffleEntered {
        //Arrange

        //Act
        vm.recordLogs();
        raffle.performUpKeep("");
        Vm.Log[] memory enteris = vm.getRecordedLogs();
        bytes32 requestId = enteris[1].topics[1];

        //Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(raffleState == Raffle.RaffleState.CALCULATING);
    }

    function testFulFillRandomWordsCanOnlyBeCalledAfterPerformUpKeep(uint256 randomRequestId)
        public
        raffleEntered
        skipFork
    {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFulFillRandomWordsToCallAndSelectTheWinnerAndResetTheRaffle() public raffleEntered skipFork {
        //Arrange
        uint160 totalPlayers = 3;
        uint160 startingIndex = 1;

        for (uint160 i = startingIndex; i < startingIndex + totalPlayers; i++) {
            address player = address(uint160(i));
            hoax(player, PLAYER_INITIAL_BALANCE);
            raffle.enterRaffle{value: INITIAL_ENTRANCE_FEE}();
        }
        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = PLAYER_INITIAL_BALANCE - INITIAL_ENTRANCE_FEE;
        //Act
        vm.recordLogs();
        raffle.performUpKeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // vm.expectRevert(Raffle.Raffle_TransferFailed.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        //Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        address recentWinner = raffle.getRecentWinner();
        uint256 winnerBalance = address(recentWinner).balance;
        uint256 endingTimestamp = raffle.getLastTimeStamp();
        uint256 totalPrizeMoney = INITIAL_ENTRANCE_FEE + (totalPlayers * INITIAL_ENTRANCE_FEE);

        assert(winnerBalance == totalPrizeMoney + winnerStartingBalance);
        assert(uint256(raffleState) == 0);
        assert(endingTimestamp > startingTimeStamp);
    }

    // function testFulFillRandomWordsToRevertAfterFailingToSendThePrizeMoney() public raffleEntered{

    // }

    modifier funder() {
        hoax(PLAYER, PLAYER_INITIAL_BALANCE);
        _;
    }

    modifier raffleEntered() {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.enterRaffle{value: INITIAL_ENTRANCE_FEE}();
        _;
    }

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAINID) {
            return;
        }
        _;
    }
}
