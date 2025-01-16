// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "./Waffle.sol";
import "./WaffleToken.sol";

/**
 * @title WaffleReferral
 * @dev Manages referral rewards for entering Waffle contracts.
 */
contract WaffleReferral {
    WaffleToken public waffleToken;
    mapping(address => uint256) public referralRewards; // Track referral rewards for each user
    mapping(address => address) public referrerOf; // Track the referrer of each user
    Waffle[] public waffles;

    /**
     * @dev Emitted when a referral reward is given.
     * @param referrer The address of the referrer.
     * @param referee The address of the referee.
     * @param reward The amount of the referral reward.
     */
    event ReferralRewarded(
        address indexed referrer,
        address indexed referee,
        uint256 reward
    );

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
    }

    /**
     * @dev Allows a user to enter a Waffle with a referral.
     * @param waffle The Waffle contract to enter.
     * @param referrer The address of the referrer.
     */
    function enterWaffleWithReferral(
        Waffle waffle,
        address referrer
    ) public payable {
        require(
            msg.value >= waffle.getEntranceFee(),
            "Not enough ETH to enter the waffle"
        );
        require(referrer != msg.sender, "You cannot refer yourself");

        if (referrer != address(0) && referrerOf[msg.sender] == address(0)) {
            referrerOf[msg.sender] = referrer; // Track the referrer of the user
            uint256 reward = msg.value / 10; // 10% of the entrance fee as reward
            referralRewards[referrer] += reward; // Track the referral reward for the referrer
            waffleToken.mint(referrer, reward);
            emit ReferralRewarded(referrer, msg.sender, reward);
        }

        waffle.enterWaffle{value: msg.value}();
    }

    /**
     * @dev Returns the referral reward for a given referrer.
     * @param referrer The address of the referrer.
     * @return The referral reward amount.
     */
    function getReferralReward(address referrer) public view returns (uint256) {
        return referralRewards[referrer];
    }

    /**
     * @dev Returns the referrer of a given referee.
     * @param referee The address of the referee.
     * @return The address of the referrer.
     */
    function getReferrerOf(address referee) public view returns (address) {
        return referrerOf[referee];
    }
}
