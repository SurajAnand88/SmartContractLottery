// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {RaffleEnterRaffle} from "../../script/Interactions.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";

contract TestIntegration is Test {
    Raffle raffle;
    HelperConfig helperConfig;
    RaffleEnterRaffle raffleEnterRaffle;
    address public PLAYER = makeAddr("Player");
    uint256 public constant PLAYER_INITIAL_BALANCE = 20 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployRaffleContract();
        raffleEnterRaffle = new RaffleEnterRaffle();
    }

    function testRaffleEnterRaffleIntegration() public {
        raffleEnterRaffle.mostRecentDeployedRaffle(address(raffle));
    }
}
