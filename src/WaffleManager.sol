// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "./Waffle.sol";
import "./WaffleToken.sol";

/**
 * @title WaffleManager
 * @dev Manages the creation and interaction with Waffle contracts.
 */
contract WaffleManager {
    Waffle[] public waffles;
    WaffleToken public waffleToken;

    /**
     * @dev Emitted when a new Waffle is created.
     * @param waffleAddress The address of the newly created Waffle contract.
     */
    event WaffleCreated(address indexed waffleAddress);

    /**
     * @dev Constructor that sets the WaffleToken contract.
     * @param _waffleToken The address of the WaffleToken contract.
     */
    constructor(WaffleToken _waffleToken) {
        waffleToken = _waffleToken;
    }

    /**
     * @dev Adds an existing Waffle contract to the manager.
     * @param waffle The Waffle contract to add.
     */
    function addWaffle(Waffle waffle) public {
        waffles.push(waffle);
        emit WaffleCreated(address(waffle));
    }

    /**
     * @dev Creates a new Waffle contract and adds it to the manager.
     * @param subscriptionId The subscription ID for the VRF.
     * @param gasLane The gas lane key hash.
     * @param interval The interval for the Waffle.
     * @param entranceFee The entrance fee for the Waffle.
     * @param callbackGasLimit The callback gas limit for the VRF.
     * @param vrfCoordinatorV2 The address of the VRF coordinator.
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
        emit WaffleCreated(address(newWaffle));
    }

    /**
     * @dev Returns the list of Waffle contracts managed by this contract.
     * @return An array of Waffle contracts.
     */
    function getWaffles() public view returns (Waffle[] memory) {
        return waffles;
    }

    /**
     * @dev Allows a user to enter a specific Waffle.
     * @param waffleIndex The index of the Waffle to enter.
     */
    function enterWaffle(uint256 waffleIndex) public payable {
        require(waffleIndex < waffles.length, "Invalid waffle index");
        Waffle waffle = waffles[waffleIndex];
        waffle.enterWaffle{value: msg.value}();
    }

    /**
     * @dev Returns details of a specific Waffle.
     * @param waffleIndex The index of the Waffle.
     * @return entranceFee The entrance fee for the Waffle.
     * @return interval The interval for the Waffle.
     * @return lastTimeStamp The last timestamp of the Waffle.
     * @return recentWinner The recent winner of the Waffle.
     * @return numberOfPlayers The number of players in the Waffle.
     * @return totalBalance The total balance of the Waffle.
     */
    function getWaffleDetails(
        uint256 waffleIndex
    )
        public
        view
        returns (
            uint256 entranceFee,
            uint256 interval,
            uint256 lastTimeStamp,
            address recentWinner,
            uint256 numberOfPlayers,
            uint256 totalBalance
        )
    {
        require(waffleIndex < waffles.length, "Invalid waffle index");
        Waffle waffle = waffles[waffleIndex];
        entranceFee = waffle.getEntranceFee();
        interval = waffle.getInterval();
        lastTimeStamp = waffle.getLastTimeStamp();
        recentWinner = waffle.getRecentWinner();
        numberOfPlayers = waffle.getNumberOfPlayers();
        totalBalance = waffle.getTotalBalance();
    }
}
