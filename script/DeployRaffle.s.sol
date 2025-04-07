// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {console} from "forge-std/console.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/CreateSubscription.s.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";

contract DeployRaffle is Script {
    function deployRaffleContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        address account = helperConfig.getConfig().account;

        if (config.subscriptionId == 0) {
            //createSubscriptionId
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId, config.vrfCoordinator) =
                createSubscription.createSubscriptionId(config.vrfCoordinator, account);

            //Fund the subscription
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(config.vrfCoordinator, config.subscriptionId, config.link);
        }

        vm.startBroadcast(config.account);
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callBackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();

        addConsumer.addConsumer(address(raffle), config.vrfCoordinator, config.subscriptionId, account);
        return (raffle, helperConfig);
    }

    function run() public {
        deployRaffleContract();
    }
}
