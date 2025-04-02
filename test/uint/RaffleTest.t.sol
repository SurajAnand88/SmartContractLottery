// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Raffle} from "src/Raffle.sol";
import {console} from "forge-std/console.sol";

contract RaffleTest is Test {
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

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        // console.log("Deploying Raffle");
        (raffle, helperConfig) = deployer.deployRaffleContract();
        // console.log("Raffle deployed at" ,address(raffle));
        // console.log("HelperConfig deployed at", address(helperConfig));
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        //vm.deal giving player initial balance which is required for transactions;
        vm.deal(PLAYER, PLAYER_INITIAL_BALANCE);
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callBackGasLimit = config.callBackGasLimit;
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

    function testDontAllowPlayersToEnterRaffleWhileRaffleIsCalculating() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: INITIAL_ENTRANCE_FEE}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpKeep("");

        //Act
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle_CalculatingWinner.selector);
        raffle.enterRaffle{value: INITIAL_ENTRANCE_FEE}();

        //Assert
    }

    modifier funder() {
        // vm.prank(PLAYER);
        // vm.deal(PLAYER, PLAYER_INITIAL_BALANCE);
        hoax(PLAYER, PLAYER_INITIAL_BALANCE);
        _;
    }
}
