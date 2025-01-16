// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "./Waffle.sol";
import "./WaffleToken.sol";
import "./WaffleManager.sol";
import "./WaffleReferral.sol";
import "./WaffleStatistics.sol";

/**
 * @title WaffleFactory
 * @notice This contract is used to create and manage Waffle instances
 */
contract WaffleFactory {
    Waffle[] public waffles;
    WaffleToken public waffleToken;
    WaffleManager public waffleManager;
    WaffleReferral public waffleReferral;
    WaffleStatistics public waffleStatistics;

    /**
     * @notice Constructor to initialize the WaffleFactory contract
     * @param _waffleToken The address of the WaffleToken contract
     * @param _waffleManager The address of the WaffleManager contract
     * @param _waffleReferral The address of the WaffleReferral contract
     * @param _waffleStatistics The address of the WaffleStatistics contract
     */
    constructor(
        WaffleToken _waffleToken,
        WaffleManager _waffleManager,
        WaffleReferral _waffleReferral,
        WaffleStatistics _waffleStatistics
    ) {
        waffleToken = _waffleToken;
        waffleManager = _waffleManager;
        waffleReferral = _waffleReferral;
        waffleStatistics = _waffleStatistics;
    }

    /**
     * @notice Function to create a new Waffle instance
     * @param subscriptionId The subscription ID for Chainlink VRF
     * @param gasLane The gas lane to use for Chainlink VRF
     * @param interval The interval between waffle runs
     * @param entranceFee The entrance fee for the waffle
     * @param callbackGasLimit The gas limit for the callback function
     * @param vrfCoordinatorV2 The address of the VRF Coordinator
     */
    function createWaffle(
        uint64 subscriptionId,
        bytes32 gasLane,
        uint256 interval,
        uint256 entranceFee,
        uint32 callbackGasLimit,
        address vrfCoordinatorV2
    ) public {
        Waffle newWaffle = new Waffle(
            subscriptionId,
            gasLane,
            interval,
            entranceFee,
            callbackGasLimit,
            vrfCoordinatorV2,
            waffleToken
        );
        waffles.push(newWaffle);
        waffleManager.addWaffle(newWaffle);
        waffleReferral.addWaffle(newWaffle);
        waffleStatistics.addWaffle(newWaffle);
    }

    /**
     * @notice Function to get all Waffle instances
     * @return An array of Waffle instances
     */
    function getWaffles() public view returns (Waffle[] memory) {
        return waffles;
    }
}
