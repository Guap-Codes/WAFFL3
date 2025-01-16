// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {DeployWaffle} from "../../script/DeployWaffle.s.sol";
import {Waffle} from "../../src/Waffle.sol";
import {WaffleToken} from "../../src/WaffleToken.sol";
import {WaffleFactory} from "../../src/WaffleFactory.sol";
import {WaffleManager} from "../../src/WaffleManager.sol";
import {WaffleReferral} from "../../src/WaffleReferral.sol";
import {WaffleStatistics} from "../../src/WaffleStatistics.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {VRFCoordinatorV2Mock} from "../mocks/VRFCoordinatorV2Mock.sol";
import {CreateSubscription} from "../../script/Interactions.s.sol";

/**
 * @title WaffleStagingTest
 * @notice This contract contains staging tests for the Waffle raffle system
 * @dev This contract inherits from StdCheats and Test for testing utilities
 */
contract WaffleStagingTest is StdCheats, Test {
    /* Events */
    /**
     * @notice Emitted when a winner is requested
     * @param requestId The ID of the request
     */
    event RequestedWaffleWinner(uint256 indexed requestId);

    /**
     * @notice Emitted when a player enters the waffle
     * @param player The address of the player
     */
    event WaffleEnter(address indexed player);

    /**
     * @notice Emitted when a winner is picked
     * @param player The address of the winner
     */
    event WinnerPicked(address indexed player);

    /* State Variables */
    /**
     * @notice The Waffle contract instance
     */
    Waffle public waffle;

    /**
     * @notice The WaffleToken contract instance
     */
    WaffleToken public waffleToken;

    /**
     * @notice The WaffleFactory contract instance
     */
    WaffleFactory public waffleFactory;

    /**
     * @notice The WaffleManager contract instance
     */
    WaffleManager public waffleManager;

    /**
     * @notice The WaffleReferral contract instance
     */
    WaffleReferral public waffleReferral;

    /**
     * @notice The WaffleStatistics contract instance
     */
    WaffleStatistics public waffleStatistics;

    /**
     * @notice The HelperConfig contract instance
     */
    HelperConfig public helperConfig;

    /**
     * @notice The subscription ID
     */
    uint64 subscriptionId;

    /**
     * @notice The gas lane
     */
    bytes32 gasLane;

    /**
     * @notice The automation update interval
     */
    uint256 automationUpdateInterval;

    /**
     * @notice The waffle entrance fee
     */
    uint256 waffleEntranceFee;

    /**
     * @notice The callback gas limit
     */
    uint32 callbackGasLimit;

    /**
     * @notice The VRF coordinator address
     */
    address vrfCoordinatorV2;

    /**
     * @notice The player address
     */
    address public PLAYER = makeAddr("player");

    /**
     * @notice The starting user balance
     */
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    /**
     * @notice Sets up the testing environment
     * @dev Deploys all necessary contracts and configures initial state
     */
    function setUp() external {
        DeployWaffle deployer = new DeployWaffle();
        (waffle, helperConfig) = deployer.run();
        vm.deal(PLAYER, STARTING_USER_BALANCE);

        (
            ,
            gasLane,
            automationUpdateInterval,
            waffleEntranceFee,
            callbackGasLimit,
            vrfCoordinatorV2, // link
            // deployerKey
            ,

        ) = helperConfig.activeNetworkConfig();

        // Deploy WaffleToken
        waffleToken = new WaffleToken();

        // Deploy WaffleManager
        waffleManager = new WaffleManager(waffleToken);

        // Deploy WaffleReferral
        waffleReferral = new WaffleReferral(waffleToken);

        // Deploy WaffleStatistics
        waffleStatistics = new WaffleStatistics(waffleManager);

        // Deploy WaffleFactory
        waffleFactory = new WaffleFactory(
            waffleToken,
            waffleManager,
            waffleReferral,
            waffleStatistics
        );

        // Create a new Waffle instance using the factory
        waffleFactory.createWaffle(
            subscriptionId,
            gasLane,
            automationUpdateInterval,
            waffleEntranceFee,
            callbackGasLimit,
            vrfCoordinatorV2
        );

        // Get the newly created Waffle instance
        Waffle[] memory waffles = waffleFactory.getWaffles();
        waffle = waffles[waffles.length - 1];
    }

    /**
     * @notice Modifier to simulate a player entering the waffle
     * @dev Sets up test state with a player entered and time advanced
     */
    modifier waffleEntered() {
        vm.prank(PLAYER);
        waffle.enterWaffle{value: waffleEntranceFee}();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        _;
    }

    /**
     * @notice Modifier to run tests only on deployed contracts
     * @dev Skips tests when running on local network or fork
     */
    modifier onlyOnDeployedContracts() {
        if (block.chainid == 31337) {
            return;
        }
        try vm.activeFork() returns (uint256) {
            return;
        } catch {
            _;
        }
    }

    /**
     * @notice Tests that fulfillRandomWords can only be called after performUpkeep
     * @dev Verifies VRF coordinator behavior for non-existent requests
     */
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep()
        public
        waffleEntered
        onlyOnDeployedContracts
    {
        // Arrange
        // Act / Assert
        vm.expectRevert("nonexistent request");
        // vm.mockCall could be used here...
        VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(
            0,
            address(waffle)
        );

        vm.expectRevert("nonexistent request");

        VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(
            1,
            address(waffle)
        );
    }

    /**
     * @notice Tests the complete winner selection process
     * @dev Verifies:
     * - Winner is correctly picked
     * - State is properly reset
     * - Prize money is correctly transferred
     * - Timestamps are updated
     */
    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        waffleEntered
        onlyOnDeployedContracts
    {
        address expectedWinner = address(1);

        // Arrange
        uint256 additionalEntrances = 3;
        uint256 startingIndex = 1; // We have starting index be 1 so we can start with address(1) and not address(0)

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrances;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, 1 ether); // deal 1 eth to the player
            waffle.enterWaffle{value: waffleEntranceFee}();
        }

        uint256 startingTimeStamp = waffle.getLastTimeStamp();
        uint256 startingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        waffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1]; // get the requestId from the logs

        VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(
            uint256(requestId),
            address(waffle)
        );

        // Assert
        address recentWinner = waffle.getRecentWinner();
        Waffle.WaffleState waffleState = waffle.getWaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = waffle.getLastTimeStamp();
        uint256 prize = waffleEntranceFee * (additionalEntrances + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(waffleState) == 0);
        assert(winnerBalance == startingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
