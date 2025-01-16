// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

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
 * @title WaffleTest
 * @dev Unit tests for the Waffle contract.
 */
contract WaffleTest is StdCheats, Test {
    /* Errors */
    event RequestedWaffleWinner(uint256 indexed requestId);
    event WaffleEnter(address indexed player);
    event WinnerPicked(address indexed player);

    Waffle public waffle;
    WaffleToken public waffleToken;
    WaffleFactory public waffleFactory;
    WaffleManager public waffleManager;
    WaffleReferral public waffleReferral;
    WaffleStatistics public waffleStatistics;
    HelperConfig public helperConfig;

    DeployWaffle.Config public config;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    /**
     * @dev Sets up the test environment by deploying the Waffle contract and configuring the helper.
     */
    function setUp() external {
        DeployWaffle deployer = new DeployWaffle();
        (waffle, helperConfig) = deployer.run();
        config = deployer.getConfig(helperConfig);
        vm.deal(PLAYER, STARTING_USER_BALANCE);

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

        // Create a new Waffle instance using the factory with subscription ID 1
        waffleFactory.createWaffle(
            1, // Use subscription ID 1 that was created in DeployWaffle.run()
            config.gasLane,
            config.automationUpdateInterval,
            config.waffleEntranceFee,
            config.callbackGasLimit,
            config.vrfCoordinatorV2
        );

        // Get the newly created Waffle instance
        Waffle[] memory waffles = waffleFactory.getWaffles();
        waffle = waffles[waffles.length - 1];

        // Transfer ownership of WaffleToken to the Waffle contract
        waffleToken.transferOwnership(address(waffle));

        // Add the consumer to the VRFCoordinatorV2Mock with subscription ID 1
        // We need to use the deployer's account since it owns the subscription
        vm.startBroadcast(config.deployerKey);
        VRFCoordinatorV2Mock(config.vrfCoordinatorV2).addConsumer(
            1, // Use subscription ID 1
            address(waffle)
        );
        vm.stopBroadcast();
    }

    /////////////////////////
    // enterWaffle         //
    /////////////////////////

    /**
     * @dev Tests that the Waffle contract reverts when not enough ETH is sent to enter.
     */
    function testWaffleRevertsWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER);
        // Act / Assert
        vm.expectRevert(Waffle.Waffle__SendMoreToEnterWaffle.selector);
        waffle.enterWaffle();
    }

    /**
     * @dev Tests that the Waffle contract records the player when they enter.
     */
    function testWaffleRecordsPlayerWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        waffle.enterWaffle{value: config.waffleEntranceFee}();
        // Assert
        address playerRecorded = waffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    /**
     * @dev Tests that the Waffle contract emits an event when a player enters.
     */
    function testEmitsEventOnEntrance() public {
        // Arrange
        vm.prank(PLAYER);

        // Act / Assert
        vm.expectEmit(true, false, false, false, address(waffle));
        emit WaffleEnter(PLAYER);
        waffle.enterWaffle{value: config.waffleEntranceFee}();
    }

    /**
     * @dev Tests that players cannot enter the Waffle while it is calculating.
     */
    function testDontAllowPlayersToEnterWhileWaffleIsCalculating() public {
        // Arrange
        vm.prank(PLAYER);
        waffle.enterWaffle{value: config.waffleEntranceFee}();
        vm.warp(block.timestamp + config.automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        waffle.performUpkeep(abi.encode(config.automationUpdateInterval));

        // Act / Assert
        vm.expectRevert(Waffle.Waffle__WaffleNotOpen.selector);
        vm.prank(PLAYER);
        waffle.enterWaffle{value: config.waffleEntranceFee}();
    }

    /////////////////////////
    // checkUpkeep         //
    /////////////////////////

    /**
     * @dev Tests that checkUpkeep returns false if the contract has no balance.
     */
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + config.automationUpdateInterval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = waffle.checkUpkeep(
            abi.encode(config.automationUpdateInterval)
        );

        // Assert
        assert(!upkeepNeeded);
    }

    /**
     * @dev Tests that checkUpkeep returns false if the Waffle is not open.
     */
    function testCheckUpkeepReturnsFalseIfWaffleIsntOpen() public {
        // Arrange
        vm.prank(PLAYER);
        waffle.enterWaffle{value: config.waffleEntranceFee}();
        vm.warp(block.timestamp + config.automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        waffle.performUpkeep(abi.encode(config.automationUpdateInterval));
        Waffle.WaffleState waffleState = waffle.getWaffleState();
        // Act
        (bool upkeepNeeded, ) = waffle.checkUpkeep(
            abi.encode(config.automationUpdateInterval)
        );
        // Assert
        assert(waffleState == Waffle.WaffleState.CALCULATING);
        assert(upkeepNeeded == false);
    }

    /**
     * @dev Tests that checkUpkeep returns false if not enough time has passed.
     */
    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        // Arrange
        vm.prank(PLAYER);
        waffle.enterWaffle{value: config.waffleEntranceFee}();
        // Act
        (bool upkeepNeeded, ) = waffle.checkUpkeep(
            abi.encode(config.automationUpdateInterval - 1)
        );
        // Assert
        assert(!upkeepNeeded);
    }

    /**
     * @dev Tests that checkUpkeep returns true when all parameters are good.
     */
    function testCheckUpkeepReturnsTrueWhenParametersGood() public {
        // Arrange
        vm.prank(PLAYER);
        waffle.enterWaffle{value: config.waffleEntranceFee}();
        vm.warp(block.timestamp + config.automationUpdateInterval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = waffle.checkUpkeep(
            abi.encode(config.automationUpdateInterval)
        );

        // Assert
        assert(upkeepNeeded);
    }

    /////////////////////////
    // performUpkeep       //
    /////////////////////////

    /**
     * @dev Tests that performUpkeep can only run if checkUpkeep is true.
     */
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // Arrange
        vm.prank(PLAYER);
        waffle.enterWaffle{value: config.waffleEntranceFee}();
        vm.warp(block.timestamp + config.automationUpdateInterval + 1);
        vm.roll(block.number + 1);

        // Act / Assert
        // It doesnt revert
        waffle.performUpkeep(abi.encode(config.automationUpdateInterval));
    }

    /**
     * @dev Tests that performUpkeep reverts if checkUpkeep is false.
     */
    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Waffle.WaffleState rState = waffle.getWaffleState();
        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Waffle.Waffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                rState
            )
        );
        waffle.performUpkeep(abi.encode(config.automationUpdateInterval));
    }

    /**
     * @dev Tests that performUpkeep updates the Waffle state and emits a requestId.
     */
    function testPerformUpkeepUpdatesWaffleStateAndEmitsRequestId() public {
        // Arrange
        vm.prank(PLAYER);
        waffle.enterWaffle{value: config.waffleEntranceFee}();
        vm.warp(block.timestamp + config.automationUpdateInterval + 1);
        vm.roll(block.number + 1);

        // Act
        vm.recordLogs();
        waffle.performUpkeep(abi.encode(config.automationUpdateInterval)); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Waffle.WaffleState waffleState = waffle.getWaffleState();
        // requestId = waffle.getLastRequestId();
        assert(uint256(requestId) > 0);
        assert(uint(waffleState) == 1); // 0 = open, 1 = calculating
    }

    /////////////////////////
    // fulfillRandomWords //
    ////////////////////////

    /**
     * @dev Modifier to ensure a player has entered the Waffle.
     */
    modifier waffleEntered() {
        vm.prank(PLAYER);
        waffle.enterWaffle{value: config.waffleEntranceFee}();
        vm.warp(block.timestamp + config.automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        _;
    }

    /**
     * @dev Modifier to skip tests on forked networks.
     */
    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    /**
     * @dev Tests that fulfillRandomWords can only be called after performUpkeep.
     */
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep()
        public
        waffleEntered
        skipFork
    {
        // Arrange
        // Act / Assert
        vm.expectRevert("nonexistent request");
        // vm.mockCall could be used here...
        VRFCoordinatorV2Mock(config.vrfCoordinatorV2).fulfillRandomWords(
            0,
            address(waffle)
        );

        vm.expectRevert("nonexistent request");

        VRFCoordinatorV2Mock(config.vrfCoordinatorV2).fulfillRandomWords(
            1,
            address(waffle)
        );
    }

    /**
     * @dev Tests that fulfillRandomWords picks a winner, resets the Waffle, and sends the prize money.
     */
    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        waffleEntered
        skipFork
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
            waffle.enterWaffle{value: config.waffleEntranceFee}();
        }

        uint256 startingTimeStamp = waffle.getLastTimeStamp();
        uint256 startingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        waffle.performUpkeep(abi.encode(config.automationUpdateInterval)); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1]; // get the requestId from the logs

        VRFCoordinatorV2Mock(config.vrfCoordinatorV2).fulfillRandomWords(
            uint256(requestId),
            address(waffle)
        );

        // Assert
        address recentWinner = waffle.getRecentWinner();
        Waffle.WaffleState waffleState = waffle.getWaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = waffle.getLastTimeStamp();
        uint256 prize = config.waffleEntranceFee * (additionalEntrances + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(waffleState) == 0);
        assert(winnerBalance == startingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
