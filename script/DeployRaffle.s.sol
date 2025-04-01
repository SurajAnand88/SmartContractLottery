// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {console} from "forge-std/console.sol";

contract DeployRaffle is Script {
    function deployRaffleContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callBackGasLimit
        );
        vm.stopBroadcast();
        return (raffle, helperConfig);
    }

    function run() public returns (Raffle) {
        // HelperConfig helperConfig = new HelperConfig();
        // HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        // Raffle raffle = new Raffle(
        //     config.entranceFee,
        //     config.interval,
        //     config.vrfCoordinator,
        //     config.gasLane,
        //     config.subscriptionId,
        //     config.callBackGasLimit
        // );
        // return raffle;
    }
}
