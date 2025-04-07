// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Console.sol";
import {HelperConfig, GetChainIds} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/Mocks/LinkToken.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionFromHelperConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;
        (uint256 subId,) = createSubscriptionId(vrfCoordinator, account);
        return (subId, vrfCoordinator);
    }

    function createSubscriptionId(address vrfCoordinator, address account) public returns (uint256, address) {
        vm.startBroadcast(account);
        console.log("creating subscriptionID");
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Your subscription id is", subId);
        console.log("Please update the subscription id in Helperconfig.s.sol");
        return (subId, vrfCoordinator);
    }

    function run() public {
        createSubscriptionFromHelperConfig();
    }
}

contract FundSubscription is GetChainIds, Script {
    uint256 public constant FUNDED_AMOUNT = 10 ether;

    function addFundToSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address linkToken = helperConfig.getConfig().link;
        fundSubscription(vrfCoordinator, subscriptionId, linkToken);
    }

    function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address linkToken) public {
        console.log("Funding subscription", subscriptionId);
        console.log("Using vrfCoordinator", vrfCoordinator);
        console.log("Using chainId", block.chainid);

        if (block.chainid == LOCAL_CHAINID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUNDED_AMOUNT * 10);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUNDED_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }

    function run() public {
        addFundToSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address mostRecentDeployedContract) public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address account = helperConfig.getConfig().account;
        addConsumer(mostRecentDeployedContract, vrfCoordinator, subId, account);
    }

    function addConsumer(address contractToAddConsumer, address vrfCoordinator, uint256 subscriptionId, address account)
        public
    {
        console.log("Adding consumer :", contractToAddConsumer);
        console.log("Adding consumer to vrfCoordinator: ", vrfCoordinator);
        console.log("To ChainId ", block.chainid);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subscriptionId, contractToAddConsumer);
        vm.stopBroadcast();
    }

    function run() external {
        address mostRecentDeployedContract = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentDeployedContract);
    }
}
