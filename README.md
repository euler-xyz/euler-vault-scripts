# Cluster Deployment and Management

This README explains how to manage a cluster using the provided scripts.

## Overview

A cluster is a collection of vaults that accept each other as collateral and have a common governor. The `ManageClusterBase.s.sol` contract defined in the `evk-periphery` repository provides the base functionality for deploying, configuring and managing clusters, while specific cluster implementations (i.e. `Cluster.s.sol`) define the actual configuration for each cluster.

## Management Process

Refer to the `defineCluster()` and `configureCluster()` functions in the specific cluster script file. If no vaults are deployed yet, they will get deployed when the management script is executed for the first time. If the vaults are already deployed, the management script will only apply the delta between the cluster script file configuration and the current state of the cluster.

Edit the specific cluster file (e.g., `Cluster.s.sol`) to set up the desired configuration. Define assets, LTVs, oracle providers, supply caps, borrow caps, IRM parameters, and other settings.

Note that the cluster specific contracts depend on the `Addresses.s.sol` which defines the asset addresses. You might need to either expand the `AddressesEthereum` contract to include more addresses on mainnet or create a new dedicated contract for new network (i.e. `AddressesBase`) and allow the `Cluster` contract to inherit from it.

If you are creating a new cluster, it's best to copy the provided `Cluster.s.sol` and start editing it from top to bottom.

The corresponding `.json` files in the scripts directory that are created when running the script are used as the deployed contracts addresses cache. They are used for further management of the cluster. They must be retained as this is how the existing contract addresses are being loaded into the cluster management script hence after the cluster deployment, commit them!

## Prerequisites

1. Ensure that you have up to date foundry version installed:

```bash
foundryup
```

If you don't have foundry installed at all, before running `foundryup`, you need to first run:

```bash
curl -L https://foundry.paradigm.xyz | bash
```

2. Clone the repository if you don't have it already:

```bash
git clone https://github.com/euler-xyz/euler-vault-scripts.git && cd euler-vault-scripts
```

3. Prepare the `.env` file. Use `.env.example` as an example: 
- define the RPC URLs for all the chain IDs you need
- if you're planning to use Safe, define `SAFE_API_KEY` by signing up [here](https://developer.safe.global/)

> **Note**: Environment variables defined in `.env` take precedence over command line arguments.

4. Ensure that you have up to date dependencies installed:

```bash
./install.sh
```

5. Compile the contracts:

```bash
forge clean && forge compile
```

## Run the script

Use the `ExecuteSolidityScript.sh` script to run the management script.

Use the following command:

```bash
./script/ExecuteSolidityScript.sh script/clusters/<ClusterSpecificScript> [options]
```

Replace `<ClusterSpecificScript>` with the cluster specific file name, i.e. `Cluster.s.sol`.

Options:
- `--dry-run`: Simulates the script without actually executing transactions.
- `--rpc-url URL|CHAIN_ID`: Must be used if `DEPLOYMENT_RPC_URL` not defined in `.env`. If `CHAIN_ID` passed, it will get resolved as per `.env`.
- `--account ACCOUNT` or `--ledger`: Must be used if `DEPLOYER_KEY` not defined in `.env` and the transaction if not meant to be executed via Safe (no actual transaction executed on-chain).
- `--batch-via-safe`: Creates a batch payload file that can be used to create a batch transaction via Safe. This option must be used in case the cluster is managed using Safe  (even if not directly; i.e. Safe is a proposer on the timelock controller).
- `--safe-address SAFE_ADDRESS`: Authorized Safe multisig address that will be used to create a batch transaction This option must be used in case the cluster is managed using Safe (even if not directly; i.e. Safe is a proposer on the timelock controller).
- `--timelock-address`: Schedules the transactions in the timelock controller provided instead of trying to execute them immediately. This option must be used in case the timelock controller is installed as part of the governor contracts suite.
- `--risk-steward-address`: Executes the transactions via the risk steward contract provided instead of trying to execute it directly. This option can be used in case the risk steward contract is installed as part of the governor contracts suite and the operation executed allows bypassing timelocks.

Example - initial deployment:

```
./script/ExecuteSolidityScript.sh ./script/clusters/Cluster.s.sol --account DEPLOYER --rpc-url 1
```

Example - management of the deployed cluster after the governance transferred to the governance contracts suite (GovernorAccessControl + TimelockController + Safe):

```
./script/ExecuteSolidityScript.sh ./script/clusters/Cluster.s.sol --batch-via-safe --safe-address DAO --timelock-address wildcard --rpc-url 1
```

## Important Notes

Always try to use the `--dry-run` option first to simulate the transactions and check for any potential issues.

# Emergency Vault Pause

In case of a governor contract installed, this section assumes that the cluster is governed by the `GovernorAccessControlEmergency` contract with a Safe multisig having an appropriate emergency role granted to it.

## Steps

1. Ensure that you performed all the steps from the Prerequisites section.

2. Run the script:

Options:
- `--rpc-url` required if `DEPLOYMENT_RPC_URL` not defined in `.env`
- `--account ACCOUNT` or `--ledger` if `DEPLOYER_KEY` not defined in `.env` and the transaction if not meant to be executed via Safe
- `--batch-via-safe` if operations must be executed via Safe multisig (typically should always be used)
- `--safe-address SAFE_ADDRESS` authorized Safe multisig address
- `--vault-address VAULT_ADDRESS` the vault being a subject of the emegency operation
- `--emergency-ltv-collateral` should be used if you intend to disable the `VAULT_ADDRESS` from being used as collateral by modifying the borrow LTVs
- `--emergency-ltv-borrowing` should be used if you intend to disable all collaterals on the `VAULT_ADDRESS` by modifying the borrow LTVs
- `--emergency-caps` should be used if you intend to set the supply and the borrow caps of the `VAULT_ADDRESS` to zero
- `--emergency-operations` should be used if you intend disable all the operations of the `VAULT_ADDRESS`

```bash
./script/ExecuteSolidityScript.sh PATH_TO_CLUSTER_SPECIFIC_SCRIPT --rpc-url RPC_URL --batch-via-safe --safe-address SAFE_ADDRESS --vault-address VAULT_ADDRESS [--emergency-ltv-collateral] [--emergency-ltv-borrowing] [--emergency-caps] [--emergency-operations]
```

Example command:

```bash
./script/ExecuteSolidityScript.sh script/clusters/Cluster.s.sol --rpc-url https://ethereum-rpc.publicnode.com --batch-via-safe --safe-address 0xB1345E7A4D35FB3E6bF22A32B3741Ae74E5Fba27 --vault-address 0xD8b27CF359b7D15710a5BE299AF6e7Bf904984C2 --emergency-ltv-collateral --emergency-caps
```

3. Create the transaction in the Safe UI (if the transaction if meant to be executed via Safe)

Use the Safe UI Transaction Builder tool to create the transaction. Load the `<payload file>` file created by the script that can be found under the following path: `deployments/[CLUSTER_SPECIFIC_DIRECTORY]/[CHAIN_ID]/output/SafeBatchBuilder_*.json`.

4. Coordinate signing process with the other Safe multisig signers.

5. Execute the transaction in the Safe UI.

# Self-Collateralization Vault Setup

The `SelfCollateralization.s.sol` script deploys a specialized vault structure consisting of two vaults for the same asset:

1. **Escrowed Collateral Vault**: A standard vault that holds the asset as collateral
2. **Borrowable Vault**: A vault that accepts the escrowed collateral vault as collateral, allowing users to borrow the same asset

This setup creates the perfect vault structure for EulerSwap, enabling self-collateralized positions where the liquidity provider (typically the DAO behind the token) can borrow an asset against their own escrowed position of the same asset.

## Use Case: EulerSwap Integration

This structure is particularly useful for creating liquidity pools where:

- A DAO can deposit assets (e.g., EUL tokens) into the escrow vault as collateral
- The borrowable vault can then be used to borrow the same asset (EUL) against the escrowed position
- This enables Just-In-Time (JIT) liquidity provision for trading pairs (e.g., WETH-EUL)
- The DAO can borrow EUL as needed from the community to facilitate swaps
- Interest rate models can be configured as the DAO sees it fit, with APY enough to attract token liquidity into the borrowable vault

## Key Benefits

- **Cost-effective liquidity provision**: DAOs can provide deep liquidity for their tokens without requiring large capital outlays
- **Token holder incentives**: The interest rate model on the borrowable vault incentivizes token holders to deposit their tokens, creating a natural yield mechanism
- **Self-collateralized efficiency**: The DAO can borrow against their own escrowed position, enabling flexible liquidity management
- **Community-driven liquidity**: Token holders become liquidity providers through the borrowable vault, creating a sustainable ecosystem

## Usage

To use the SelfCollateralization script:

1. Edit the `SelfCollateralization.s.sol` file and modify the `TOKEN` and `IRM` addresses to your desired asset and interest rate model
2. Run the script using the standard execution command:

```bash
./script/ExecuteSolidityScript.sh ./script/self-collateralization/SelfCollateralization.s.sol [options]
```

i.e.
```bash
./script/ExecuteSolidityScript.sh ./script/self-collateralization/SelfCollateralization.s.sol --account DEPLOYER --rpc-url 1
```

# Troubleshooting

If you are already using `euler-vault-scripts` and your scripts began failing due to changes in the Safe API, you likely need to update your local copy of the repository. If you are working from your own fork, make sure to pull the latest changes from the upstream `euler-xyz/euler-vault-scripts` repository. This will ensure you have the most recent fixes and compatibility updates for the Safe API. After updating, reinstall dependencies and recompile the contracts to ensure everything works as expected. Note that you may need to add `SAFE_API_KEY` to your `.env` file as explained in the [Prerequisites](#prerequisites) section above.

# Safety

This software is experimental and is provided "as is" and "as available".

No warranties are provided and no liability will be accepted for any loss incurred through the use of this codebase.

Always include thorough tests when using provided software to ensure it works as intended.
