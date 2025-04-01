// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";
import {Raffle} from "src/Raffle.sol";

contract RaffleEnterRaffle is Script {
    uint256 public constant ENTER_RAFFLE_VALUE = 0.2 ether;
    address public PLAYER = makeAddr("Player");
    uint256 public constant PLAYER_INITIAL_BALANCE = 20 ether;

    function mostRecentDeployedRaffle(address recentDeployed) public {
        vm.deal(PLAYER, PLAYER_INITIAL_BALANCE);
        vm.prank(address(PLAYER));
        Raffle(recentDeployed).enterRaffle{value: ENTER_RAFFLE_VALUE}();
        console.log("entered raffle with the value", ENTER_RAFFLE_VALUE);
    }

    function run() external {
        address recentDeployment = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        vm.startBroadcast();
        mostRecentDeployedRaffle(recentDeployment);
        vm.stopBroadcast();
    }
}

contract RaffleChooseWinnerRaffle is Script {
    function run() external {}
}
