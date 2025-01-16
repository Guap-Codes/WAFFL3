// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "./WaffleToken.sol";

/**
 * @title WAFFL3: A Waffle themed Raffle Contract
 * @notice This contract is for creating a sample waffle-themed raffle contract
 * @dev This contract implements the Chainlink VRF Version 2 and Chainlink Automation
 */
contract Waffle is VRFConsumerBaseV2, AutomationCompatibleInterface, Ownable {
    /* Errors */
    error Waffle__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 waffleState
    );
    error Waffle__TransferFailed();
    error Waffle__SendMoreToEnterWaffle();
    error Waffle__WaffleNotOpen();

    /* Type declarations */
    enum WaffleState {
        OPEN,
        CALCULATING
    }

    /* State variables */
    // Chainlink VRF Variables
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    // Lottery Variables
    uint256 private immutable i_interval;
    uint256 private immutable i_entranceFee;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    address payable[] private s_players; // Array to track users who entered the raffle
    WaffleState private s_waffleState;

    // WaffleToken Variables
    WaffleToken private waffleToken;
    uint256 private constant TOKEN_REWARD = 100 * (10 ** 18); // Reward 100 tokens to the winner

    /* Events */
    event RequestedWaffleWinner(uint256 indexed requestId);
    event WaffleEnter(address indexed player);
    event WinnerPicked(address indexed player);

    /**
     * @notice Constructor to initialize the Waffle contract
     * @param subscriptionId The subscription ID for Chainlink VRF
     * @param gasLane The gas lane to use for Chainlink VRF
     * @param interval The interval between waffle runs
     * @param entranceFee The entrance fee for the waffle
     * @param callbackGasLimit The gas limit for the callback function
     * @param vrfCoordinatorV2 The address of the VRF Coordinator
     * @param _waffleToken The address of the WaffleToken contract
     */
    constructor(
        uint64 subscriptionId,
        bytes32 gasLane, // keyHash
        uint256 interval,
        uint256 entranceFee,
        uint32 callbackGasLimit,
        address vrfCoordinatorV2,
        WaffleToken _waffleToken
    ) VRFConsumerBaseV2(vrfCoordinatorV2) Ownable(msg.sender) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_interval = interval;
        i_subscriptionId = subscriptionId;
        i_entranceFee = entranceFee;
        s_waffleState = WaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_callbackGasLimit = callbackGasLimit;
        waffleToken = _waffleToken;
    }

    /**
     * @notice Function to enter the waffle
     * @dev Adds the sender to the list of players and emits the WaffleEnter event
     */
    function enterWaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Waffle__SendMoreToEnterWaffle();
        }
        if (s_waffleState != WaffleState.OPEN) {
            revert Waffle__WaffleNotOpen();
        }
        s_players.push(payable(msg.sender)); // Track user by adding their address to the array
        emit WaffleEnter(msg.sender);
    }

    /**
     * @notice Function to check if upkeep is needed
     * @dev This is the function that the Chainlink Keeper nodes call
     * @param checkData Data passed to the function to customize its behavior
     * @return upkeepNeeded Boolean indicating if upkeep is needed
     * @return performData Data to be passed to performUpkeep
     */
    function checkUpkeep(
        bytes memory checkData
    )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        // Decode the checkData to extract any parameters
        uint256 customInterval = abi.decode(checkData, (uint256));

        bool isOpen = WaffleState.OPEN == s_waffleState;
        bool timePassed = ((block.timestamp - s_lastTimeStamp) >
            customInterval);
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (timePassed && isOpen && hasBalance && hasPlayers);

        // Encode any data to be passed to performUpkeep
        performData = abi.encode(customInterval);

        return (upkeepNeeded, performData);
    }

    /**
     * @notice Function to perform upkeep
     * @dev Once `checkUpkeep` is returning `true`, this function is called
     * and it kicks off a Chainlink VRF call to get a random winner.
     * @param performData Data passed from checkUpkeep to performUpkeep
     */
    function performUpkeep(bytes calldata performData) external override {
        (bool upkeepNeeded, ) = checkUpkeep(performData);
        if (!upkeepNeeded) {
            revert Waffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_waffleState)
            );
        }
        s_waffleState = WaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestedWaffleWinner(requestId);
    }

    /**
     * @notice Function to fulfill random words
     * @dev This is the function that Chainlink VRF node calls to send the money to the random winner.
     * @param requestId The ID of the VRF request
     * @param randomWords The random words generated by Chainlink VRF
     */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_players = new address payable[](0);
        s_waffleState = WaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(recentWinner);
        emit RequestedWaffleWinner(requestId); // Log the requestId
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Waffle__TransferFailed();
        }
        waffleToken.mint(recentWinner, TOKEN_REWARD); // Mint tokens to the winner
    }

    /**
     * @notice Allows the owner to withdraw funds from the contract
     * @dev Only callable by the owner
     */
    function withdrawFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        if (!success) {
            revert Waffle__TransferFailed();
        }
    }

    /**
     * @notice Returns the list of all players who have entered the waffle
     * @return An array of addresses of players
     */
    function getAllPlayers() public view returns (address payable[] memory) {
        return s_players; // Return the array of users who entered the raffle
    }

    /**
     * @notice Returns the total balance of the contract
     * @return The balance of the contract in wei
     */
    function getTotalBalance() public view returns (uint256) {
        return address(this).balance;
    }

    /** Getter Functions */

    /**
     * @notice Returns the current state of the waffle
     * @return The current state of the waffle
     */
    function getWaffleState() public view returns (WaffleState) {
        return s_waffleState;
    }

    /**
     * @notice Returns the number of random words requested
     * @return The number of random words requested
     */
    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    /**
     * @notice Returns the number of confirmations required for the VRF request
     * @return The number of confirmations required for the VRF request
     */
    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    /**
     * @notice Returns the WaffleToken contract
     * @return The WaffleToken contract
     */
    function getWaffleToken() public view returns (WaffleToken) {
        return waffleToken;
    }

    /**
     * @notice Returns the most recent winner of the waffle
     * @return The address of the most recent winner
     */
    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    /**
     * @notice Returns the address of a player at a given index
     * @param index The index of the player
     * @return The address of the player at the given index
     */
    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    /**
     * @notice Returns the last timestamp when the waffle was run
     * @return The last timestamp when the waffle was run
     */
    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    /**
     * @notice Returns the interval between waffle runs
     * @return The interval between waffle runs
     */
    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    /**
     * @notice Returns the entrance fee for the waffle
     * @return The entrance fee for the waffle
     */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    /**
     * @notice Returns the number of players in the waffle
     * @return The number of players in the waffle
     */
    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }
}
