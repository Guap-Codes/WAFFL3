// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "./Waffle.sol";
import "./WaffleManager.sol";
import "./WaffleFactory.sol";

/**
 * @title WaffleStatistics
 * @dev Provides statistics and historical data for Waffle contracts.
 */
contract WaffleStatistics {
    Waffle[] public waffles;
    WaffleManager public waffleManager;

    /**
     * @dev Emitted when a new Waffle is added to the statistics.
     * @param waffleAddress The address of the newly added Waffle contract.
     */
    event WaffleCreated(address indexed waffleAddress);

    /**
     * @dev Constructor that sets the WaffleManager contract.
     * @param _waffleManager The address of the WaffleManager contract.
     */
    constructor(WaffleManager _waffleManager) {
        waffleManager = _waffleManager;
    }

    /**
     * @dev Adds an existing Waffle contract to the statistics.
     * @param waffle The Waffle contract to add.
     */
    function addWaffle(Waffle waffle) public {
        waffles.push(waffle);
        emit WaffleCreated(address(waffle));
    }

    /**
     * @dev Returns the total number of Waffle contracts.
     * @return The total number of Waffle contracts.
     */
    function getTotalRaffles() public view returns (uint256) {
        return waffles.length;
    }

    /**
     * @dev Returns the total funds collected by all Waffle contracts.
     * @return totalFunds The total funds collected.
     */
    function getTotalFundsCollected() public view returns (uint256 totalFunds) {
        for (uint256 i = 0; i < waffles.length; i++) {
            totalFunds += waffles[i].getTotalBalance();
        }
    }

    /**
     * @dev Returns the historical winners of all Waffle contracts.
     * @return An array of addresses of the historical winners.
     */
    function getHistoricalWinners() public view returns (address[] memory) {
        address[] memory winners = new address[](waffles.length);
        for (uint256 i = 0; i < waffles.length; i++) {
            winners[i] = waffles[i].getRecentWinner();
        }
        return winners;
    }

    /**
     * @dev Updates the list of Waffle contracts from the WaffleManager.
     */
    function updateWaffles() public {
        Waffle[] memory allWaffles = waffleManager.getWaffles();
        for (uint256 i = 0; i < allWaffles.length; i++) {
            if (!isWaffleTracked(allWaffles[i])) {
                waffles.push(allWaffles[i]);
                emit WaffleCreated(address(allWaffles[i]));
            }
        }
    }

    /**
     * @dev Checks if a Waffle contract is already tracked.
     * @param waffle The Waffle contract to check.
     * @return True if the Waffle contract is tracked, false otherwise.
     */
    function isWaffleTracked(Waffle waffle) internal view returns (bool) {
        for (uint256 i = 0; i < waffles.length; i++) {
            if (address(waffle) == address(waffles[i])) {
                return true;
            }
        }
        return false;
    }
}
