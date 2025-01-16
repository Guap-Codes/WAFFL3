# Web3 Raffle (WAFFL3)

## Overview

The Web3 Raffle project is a decentralized raffle system built on the Ethereum blockchain. It leverages Chainlink VRF (Verifiable Random Function) for randomness and Chainlink Automation for automated upkeep. The project includes several smart contracts to manage the raffle, handle referrals, track statistics, and manage tokens.

## Contracts

- **Waffle.sol**: The main raffle contract that handles entries, selects winners, and distributes rewards.
- **WaffleToken.sol**: An ERC20 token contract for the Waffle platform with minting capabilities.
- **WaffleManager.sol**: Manages the creation and interaction with Waffle contracts.
- **WaffleReferral.sol**: Manages referral rewards for entering Waffle contracts.
- **WaffleStatistics.sol**: Provides statistics and historical data for Waffle contracts.
- **WaffleFactory.sol**: Factory contract to create new Waffle instances.

## Setup

### Prerequisites

- Foundry
- An Ethereum wallet (e.g., MetaMask)
- An Ethereum node provider (e.g., Infura, Alchemy)

### Installation

1. Clone the repository:
    ```sh
    git clone https://github.com/Guap-Codes/WAFFL3.git
    cd WAFFL3
    ```

2. Install Foundry:
    ```sh
    curl -L https://foundry.paradigm.xyz | bash
    foundryup
    ```

3. Install dependencies:
    ```sh
    forge install
    ```

4. Compile the contracts:
    ```sh
    forge build
    ```

## Deployment

### Local Deployment

1. Start a local Ethereum node:
    ```sh
    anvil
    ```

2. Deploy the contracts:
    ```sh
    forge script script/DeployWaffle.s.sol --fork-url http://localhost:8545 --broadcast
    ```

### Testnet/Mainnet Deployment

1. Configure your environment variables in a `.env` file:
    ```env
    PRIVATE_KEY=your_private_key
    INFURA_PROJECT_ID=your_infura_project_id
    ```

2. Deploy the contracts:
    ```sh
    forge script script/DeployWaffle.s.sol --rpc-url https://rinkeby.infura.io/v3/$INFURA_PROJECT_ID --broadcast
    ```

## Testing

1. Run the tests:
    ```sh
    forge test
    ```

## Usage

### Entering the Raffle

1. Interact with the deployed `Waffle` contract to enter the raffle:
    ```solidity
    waffle.enterWaffle{value: entranceFee}();
    ```

### Checking Upkeep

1. Check if upkeep is needed:
    ```solidity
    (bool upkeepNeeded, ) = waffle.checkUpkeep(abi.encode(interval));
    ```

### Performing Upkeep

1. Perform upkeep to select a winner:
    ```solidity
    waffle.performUpkeep(abi.encode(interval));
    ```

### Viewing Statistics

1. Get the total number of raffles:
    ```solidity
    uint256 totalRaffles = waffleStatistics.getTotalRaffles();
    ```

2. Get the total funds collected:
    ```solidity
    uint256 totalFunds = waffleStatistics.getTotalFundsCollected();
    ```

3. Get the historical winners:
    ```solidity
    address[] memory winners = waffleStatistics.getHistoricalWinners();
    ```

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## License

This project is licensed under the MIT License.
