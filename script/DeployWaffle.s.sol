// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Waffle} from "../src/Waffle.sol";
import {WaffleToken} from "../src/WaffleToken.sol";
import {WaffleManager} from "../src/WaffleManager.sol";
import {WaffleReferral} from "../src/WaffleReferral.sol";
import {WaffleStatistics} from "../src/WaffleStatistics.sol";
import {WaffleFactory} from "../src/WaffleFactory.sol";
import {AddConsumer, CreateSubscription, FundSubscription} from "./Interactions.s.sol";

/**
 * @title DeployWaffle
 * @dev Script for deploying and configuring Waffle contracts.
 */
contract DeployWaffle is Script {
    struct Config {
        uint64 subscriptionId;
        bytes32 gasLane;
        uint256 automationUpdateInterval;
        uint256 waffleEntranceFee;
        uint32 callbackGasLimit;
        address vrfCoordinatorV2;
        address link;
        uint256 deployerKey;
    }

    /**
     * @dev Main function to run the deployment script.
     * @return The deployed Waffle contract and HelperConfig instance.
     */
    function run() external returns (Waffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!
        AddConsumer addConsumer = new AddConsumer();
        Config memory config = getConfig(helperConfig);

        if (config.subscriptionId == 0) {
            config.subscriptionId = createAndFundSubscription(
                config.vrfCoordinatorV2,
                config.link,
                config.deployerKey
            );
        }

        vm.startBroadcast(config.deployerKey);

        // Deploy WaffleToken
        WaffleToken waffleToken = new WaffleToken();

        // Deploy WaffleManager
        WaffleManager waffleManager = new WaffleManager(waffleToken);

        // Deploy WaffleReferral
        WaffleReferral waffleReferral = new WaffleReferral(waffleToken);

        // Deploy WaffleStatistics
        WaffleStatistics waffleStatistics = new WaffleStatistics(waffleManager);

        // Deploy WaffleFactory
        WaffleFactory waffleFactory = new WaffleFactory(
            waffleToken,
            waffleManager,
            waffleReferral,
            waffleStatistics
        );

        // Create a new Waffle instance using the factory
        createWaffleInstance(waffleFactory, config);

        vm.stopBroadcast();

        // Get the newly created Waffle instance
        Waffle[] memory waffles = waffleFactory.getWaffles();
        Waffle waffle = waffles[waffles.length - 1];

        // We already have a broadcast in here
        addConsumer.addConsumer(
            address(waffle),
            config.vrfCoordinatorV2,
            config.subscriptionId,
            config.deployerKey
        );

        return (waffle, helperConfig);
    }

    /**
     * @dev Retrieves the configuration for the deployment.
     * @param helperConfig The HelperConfig instance.
     * @return config The configuration struct.
     */
    function getConfig(
        HelperConfig helperConfig
    ) public view returns (Config memory config) {
        (
            config.subscriptionId,
            config.gasLane,
            config.automationUpdateInterval,
            config.waffleEntranceFee,
            config.callbackGasLimit,
            config.vrfCoordinatorV2,
            config.link,
            config.deployerKey
        ) = helperConfig.activeNetworkConfig();
    }

    /**
     * @dev Creates and funds a VRF subscription.
     * @param vrfCoordinatorV2 The address of the VRF coordinator.
     * @param link The address of the LINK token.
     * @param deployerKey The deployer's private key.
     * @return subscriptionId The created subscription ID.
     */
    function createAndFundSubscription(
        address vrfCoordinatorV2,
        address link,
        uint256 deployerKey
    ) internal returns (uint64 subscriptionId) {
        CreateSubscription createSubscription = new CreateSubscription();
        subscriptionId = createSubscription.createSubscription(
            vrfCoordinatorV2,
            deployerKey
        );

        FundSubscription fundSubscription = new FundSubscription();
        fundSubscription.fundSubscription(
            vrfCoordinatorV2,
            subscriptionId,
            link,
            deployerKey
        );
    }

    /**
     * @dev Creates a new Waffle instance using the WaffleFactory.
     * @param waffleFactory The WaffleFactory instance.
     * @param config The configuration struct.
     */
    function createWaffleInstance(
        WaffleFactory waffleFactory,
        Config memory config
    ) internal {
        waffleFactory.createWaffle(
            config.subscriptionId,
            config.gasLane,
            config.automationUpdateInterval,
            config.waffleEntranceFee,
            config.callbackGasLimit,
            config.vrfCoordinatorV2
        );
    }
}
