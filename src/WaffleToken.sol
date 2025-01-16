// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title WaffleToken
 * @dev ERC20 token for the Waffle platform with minting capabilities.
 */
contract WaffleToken is ERC20, Ownable {
    uint256 public constant INITIAL_SUPPLY = 1000000 * (10 ** 18);

    /**
     * @dev Constructor that mints the initial supply to the deployer.
     */
    constructor() ERC20("WaffleToken", "WAFFL3") Ownable(msg.sender) {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    /**
     * @dev Mints new tokens to a specified address.
     * @param to The address to mint the tokens to.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
