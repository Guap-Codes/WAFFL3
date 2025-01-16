// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployWaffle} from "../../script/DeployWaffle.s.sol";
import {Waffle} from "../../src/Waffle.sol";
import {WaffleToken} from "../../src/WaffleToken.sol";
import {VRFCoordinatorV2Mock} from "../mocks/VRFCoordinatorV2Mock.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

/**
 * @title WaffleInvariantTest
 * @notice Contract for testing invariant properties of the Waffle raffle system
 * @dev Uses Foundry's StdInvariant for property-based testing to verify system invariants
 */
contract WaffleInvariantTest is StdInvariant, Test {
    /* State Variables */
    /**
     * @notice The main Waffle contract instance
     */
    Waffle public waffle;

    /**
     * @notice The WaffleToken contract instance
     */
    WaffleToken public waffleToken;

    /**
     * @notice Mock VRF Coordinator for testing
     */
    VRFCoordinatorV2Mock public vrfCoordinator;

    /**
     * @notice Configuration helper instance
     */
    HelperConfig public helperConfig;

    /**
     * @notice Deployment configuration
     */
    DeployWaffle.Config public config;

    /**
     * @notice Array of test player addresses
     */
    address[] public players;

    /**
     * @notice Starting balance for test users
     * @dev Set to 10 ether for testing purposes
     */
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    /**
     * @notice Token reward amount for winners
     * @dev Set to 100 tokens (with 18 decimals)
     */
    uint256 public constant TOKEN_REWARD = 100 * (10 ** 18);

    /**
     * @notice Sets up the test environment
     * @dev Deploys contracts, configures VRF, transfers token ownership, and funds test addresses
     */
    function setUp() external {
        DeployWaffle deployer = new DeployWaffle();
        (waffle, helperConfig) = deployer.run();
        config = deployer.getConfig(helperConfig);
        vrfCoordinator = VRFCoordinatorV2Mock(config.vrfCoordinatorV2);
        waffleToken = WaffleToken(waffle.getWaffleToken());

        // Transfer ownership of WaffleToken to Waffle contract for minting
        vm.startBroadcast(config.deployerKey);
        waffleToken.transferOwnership(address(waffle));
        vm.stopBroadcast();

        // Fund all test addresses
        for (uint160 i = 1; i <= 10; i++) {
            address player = address(i);
            vm.deal(player, STARTING_USER_BALANCE);
            players.push(player);
        }

        targetContract(address(waffle));
    }

    /* Balance Invariants */

    /**
     * @notice Verifies that contract balance matches total entrance fees
     * @dev Ensures contract balance equals number of players times entrance fee
     */
    function invariant_balanceMatchesEntrance() public {
        uint256 playersLength = waffle.getNumberOfPlayers();
        uint256 entranceFee = waffle.getEntranceFee();
        assertEq(address(waffle).balance, playersLength * entranceFee);
    }

    /**
     * @notice Verifies winner receives correct prize pool
     * @dev Checks winner's balance increase matches contract balance after win
     */
    function invariant_winnerGetsBalance() public {
        // Only check if a winner was picked
        address winner = waffle.getRecentWinner();
        if (winner != address(0)) {
            uint256 preBalance = winner.balance;
            uint256 prizePool = address(waffle).balance;

            // Simulate winner selection
            vm.warp(block.timestamp + waffle.getInterval() + 1);
            waffle.performUpkeep("");

            assertEq(winner.balance, preBalance + prizePool);
            assertEq(address(waffle).balance, 0);
        }
    }

    /* State Invariants */

    /**
     * @notice Verifies valid state transitions
     * @dev Ensures:
     * - State is either OPEN (0) or CALCULATING (1)
     * - Cannot enter when state is CALCULATING
     */
    function invariant_stateTransitions() public {
        uint256 state = uint256(waffle.getWaffleState());
        assertTrue(state <= 1); // Only OPEN (0) or CALCULATING (1)

        if (state == 1) {
            // CALCULATING
            vm.expectRevert(Waffle.Waffle__WaffleNotOpen.selector);
            waffle.enterWaffle{value: waffle.getEntranceFee()}();
        }
    }

    /**
     * @notice Verifies state after winner selection
     * @dev Ensures state is OPEN after a winner is picked
     */
    function invariant_stateAfterWinner() public {
        if (waffle.getRecentWinner() != address(0)) {
            assertEq(uint256(waffle.getWaffleState()), 0); // Should be OPEN
        }
    }

    /* Player Invariants */

    /**
     * @notice Verifies player array reset after winner
     * @dev Ensures number of players is 0 after winner selection
     */
    function invariant_playersResetAfterWinner() public {
        if (waffle.getRecentWinner() != address(0)) {
            assertEq(waffle.getNumberOfPlayers(), 0);
        }
    }

    /**
     * @notice Verifies entrance fee requirements
     * @dev Ensures players cannot enter with less than required fee
     */
    function invariant_playerEntranceFee() public {
        uint256 entranceFee = waffle.getEntranceFee();
        for (uint256 i = 0; i < players.length; i++) {
            vm.prank(players[i]);
            vm.expectRevert(Waffle.Waffle__SendMoreToEnterWaffle.selector);
            waffle.enterWaffle{value: entranceFee - 1}();
        }
    }

    /* Token Invariants */

    /**
     * @notice Verifies winner receives correct token reward
     * @dev Ensures winner's token balance equals TOKEN_REWARD after win
     */
    function invariant_winnerTokenReward() public {
        address winner = waffle.getRecentWinner();
        if (winner != address(0)) {
            uint256 winnerBalance = waffleToken.balanceOf(winner);
            assertEq(winnerBalance, TOKEN_REWARD);
        }
    }

    /**
     * @notice Verifies token supply changes correctly
     * @dev Ensures total supply increases by TOKEN_REWARD after winner selection
     */
    function invariant_tokenSupplyIncrement() public {
        address winner = waffle.getRecentWinner();
        if (winner != address(0)) {
            uint256 totalSupply = waffleToken.totalSupply();

            // Simulate winner selection
            vm.warp(block.timestamp + waffle.getInterval() + 1);
            waffle.performUpkeep("");

            assertEq(waffleToken.totalSupply(), totalSupply + TOKEN_REWARD);
        }
    }

    /* Helper Functions */

    /**
     * @notice Gets a random player from the players array
     * @dev Uses block timestamp for randomness (not secure for production)
     * @return address Random player address
     */
    function getRandomPlayer() internal view returns (address) {
        uint256 index = uint256(keccak256(abi.encodePacked(block.timestamp))) %
            players.length;
        return players[index];
    }

    /**
     * @notice Fallback function to receive ETH
     * @dev Required for contract to receive ETH
     */
    receive() external payable {}
}
