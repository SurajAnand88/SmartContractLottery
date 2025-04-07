// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {console} from "forge-std/console.sol";
import {CreateSubscription} from "script/CreateSubscription.s.sol";
import {LinkToken} from "test/Mocks/LinkToken.sol";

abstract contract GetChainIds {
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE_LINK = 1e9;
    int256 public constant MOCK_WEI_PER_UNIT_LINK = 4e15;

    address public FOUNDRY_DEFAULT_SENDER =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    uint256 public constant ETH_SEPOLIA_CHAINID = 11155111;
    uint256 public constant LOCAL_CHAINID = 31337;
}

contract HelperConfig is Script, GetChainIds {
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callBackGasLimit;
        address link;
        address account;
    }

    constructor() {
        NetworkConfigs[ETH_SEPOLIA_CHAINID] = getSepoliaNetworkConfig();
        NetworkConfigs[LOCAL_CHAINID] = getOrCreateAnvilEthConfig();
    }

    error HelperConfig__NetworkConfigError();

    NetworkConfig public localNetworkconfig;
    mapping(uint256 chainId => NetworkConfig) public NetworkConfigs;

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory config) {
        if (NetworkConfigs[chainId].vrfCoordinator != address(0)) {
            return NetworkConfigs[chainId];
        } else if (chainId == LOCAL_CHAINID) {
            getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__NetworkConfigError();
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getSepoliaNetworkConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.2 ether, //1e16
            interval: 30,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 90408319092427918692949180483022735124383284755486992522396419863317981140589,
            callBackGasLimit: 500000,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: 0xC3Ad970d7d6f8b0807835b92d7c5D65CFc792295
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        //check to see if we have an active network config
        if (localNetworkconfig.vrfCoordinator != address(0)) {
            return localNetworkconfig;
        }

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UNIT_LINK);
        LinkToken linkToken = new LinkToken();

        vm.stopBroadcast();

        localNetworkconfig = NetworkConfig({
            entranceFee: 0.2 ether, //1e16
            interval: 30,
            vrfCoordinator: address(vrfCoordinatorMock),
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 0,
            callBackGasLimit: 500000,
            link: address(linkToken),
            account: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        });

        // console.log(address(vrfCoordinatorMock));
        // 0x34A1D3fff3958843C43aD80F30b94c510645C316
        return localNetworkconfig;
    }
}
