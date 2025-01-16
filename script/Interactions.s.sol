// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Waffle} from "../src/Waffle.sol";
import {WaffleToken} from "../src/WaffleToken.sol";
import {WaffleManager} from "../src/WaffleManager.sol";
import {WaffleReferral} from "../src/WaffleReferral.sol";
import {WaffleStatistics} from "../src/WaffleStatistics.sol";
import {WaffleFactory} from "../src/WaffleFactory.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {VRFCoordinatorV2Mock} from "../test/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

/**
 * @title CreateSubscription
 * @dev Script for creating a VRF subscription.
 */
contract CreateSubscription is Script {
    /**
     * @dev Creates a VRF subscription using the configuration.
     * @return The created subscription ID.
     */
    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            ,
            ,
            ,
            address vrfCoordinatorV2,
            ,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        return createSubscription(vrfCoordinatorV2, deployerKey);
    }

    /**
     * @dev Creates a VRF subscription.
     * @param vrfCoordinatorV2 The address of the VRF coordinator.
     * @param deployerKey The deployer's private key.
     * @return The created subscription ID.
     */
    function createSubscription(
        address vrfCoordinatorV2,
        uint256 deployerKey
    ) public returns (uint64) {
        console.log("Creating subscription on chainId: ", block.chainid);
        vm.startBroadcast(deployerKey);
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinatorV2)
            .createSubscription();
        vm.stopBroadcast();
        console.log("Your subscription Id is: ", subId);
        console.log("Please update the subscriptionId in HelperConfig.s.sol");
        return subId;
    }

    /**
     * @dev Runs the script to create a VRF subscription using the configuration.
     * @return The created subscription ID.
     */
    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}

/**
 * @title AddConsumer
 * @dev Script for adding a consumer to a VRF subscription.
 */
contract AddConsumer is Script {
    /**
     * @dev Adds a consumer to a VRF subscription.
     * @param contractToAddToVrf The address of the contract to add as a consumer.
     * @param vrfCoordinator The address of the VRF coordinator.
     * @param subId The subscription ID.
     * @param deployerKey The deployer's private key.
     */
    function addConsumer(
        address contractToAddToVrf,
        address vrfCoordinator,
        uint64 subId,
        uint256 deployerKey
    ) public {
        console.log("Adding consumer contract: ", contractToAddToVrf);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainID: ", block.chainid);
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(
            subId,
            contractToAddToVrf
        );
        vm.stopBroadcast();
    }

    /**
     * @dev Adds a consumer to a VRF subscription using the configuration.
     * @param mostRecentlyDeployed The address of the most recently deployed contract.
     */
    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint64 subId,
            ,
            ,
            ,
            ,
            address vrfCoordinatorV2,
            ,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        addConsumer(mostRecentlyDeployed, vrfCoordinatorV2, subId, deployerKey);
    }

    /**
     * @dev Runs the script to add a consumer using the configuration.
     */
    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Waffle",
            block.chainid
        );
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}

/**
 * @title FundSubscription
 * @dev Script for funding a VRF subscription.
 */
contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    /**
     * @dev Funds a VRF subscription using the configuration.
     */
    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint64 subId,
            ,
            ,
            ,
            ,
            address vrfCoordinatorV2,
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        fundSubscription(vrfCoordinatorV2, subId, link, deployerKey);
    }

    /**
     * @dev Funds a VRF subscription.
     * @param vrfCoordinatorV2 The address of the VRF coordinator.
     * @param subId The subscription ID.
     * @param link The address of the LINK token.
     * @param deployerKey The deployer's private key.
     */
    function fundSubscription(
        address vrfCoordinatorV2,
        uint64 subId,
        address link,
        uint256 deployerKey
    ) public {
        console.log("Funding subscription: ", subId);
        console.log("Using vrfCoordinator: ", vrfCoordinatorV2);
        console.log("On ChainID: ", block.chainid);
        if (block.chainid == 31337) {
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfCoordinatorV2).fundSubscription(
                subId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            console.log(LinkToken(link).balanceOf(msg.sender));
            console.log(msg.sender);
            console.log(LinkToken(link).balanceOf(address(this)));
            console.log(address(this));
            vm.startBroadcast(deployerKey);
            LinkToken(link).transferAndCall(
                vrfCoordinatorV2,
                FUND_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }

    /**
     * @dev Runs the script to fund a VRF subscription using the configuration.
     */
    function run() external {
        fundSubscriptionUsingConfig();
    }
}
