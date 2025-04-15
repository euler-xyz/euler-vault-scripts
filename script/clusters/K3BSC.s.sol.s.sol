// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageClusterBase} from "evk-periphery-scripts/production/ManageClusterBase.s.sol";
import {OracleVerifier} from "evk-periphery-scripts/utils/SanityCheckOracle.s.sol";
import "./Addresses.s.sol";

contract Cluster is ManageClusterBase, AddressesBSC {
    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/clusters/K3BSC.json";

        // after the cluster is deployed, do not change the order of the assets in the .assets array. if done, it must be 
        // reflected in other the other arrays the ltvs matrix. IMPORTANT: do not define more than one vault for the same asset
        cluster.assets = [USDT, USDC, sUSDe, USDe, USR, YUSD];
    }

    function configureCluster() internal override {
        // define the governors here
        cluster.oracleRoutersGovernor = cluster.vaultsGovernor = 0x5Bb012482Fa43c44a29168C6393657130FDF0506;

        // define unit of account here
        cluster.unitOfAccount = USD;

        // define fee receiver here and interest fee here. 
        // if needed to be defined per asset, populate the feeReceiverOverride and interestFeeOverride mappings
        cluster.feeReceiver = cluster.vaultsGovernor;
        cluster.interestFee = 0.1e4;

        // define max liquidation discount here. 
        // if needed to be defined per asset, populate the maxLiquidationDiscountOverride mapping
        cluster.maxLiquidationDiscount = 0.15e4;

        // define liquidation cool off time here. 
        // if needed to be defined per asset, populate the liquidationCoolOffTimeOverride mapping
        cluster.liquidationCoolOffTime = 1;

        // define hook target and hooked ops here. 
        // if needed to be defined per asset, populate the hookTargetOverride and hookedOpsOverride mappings
        cluster.hookTarget = address(0);
        cluster.hookedOps = 0;

        // define config flags here. if needed to be defined per asset, populate the configFlagsOverride mapping
        cluster.configFlags = 0;

        // define oracle providers here. 
        // in case the asset is an ERC4626 vault itself (i.e. sUSDS) and the convertToAssets function is meant to be used 
        // for pricing, the string should be preceeded by "ExternalVault|" prefix. this is in order to correctly resolve 
        // the asset (vault) in the oracle router. 
        // refer to https://oracles.euler.finance/ for the list of available oracle adapters
        cluster.oracleProviders[USDT ] = "0xed29690a4d7f1b63807957fb71149a8dcfd820a4";
        cluster.oracleProviders[USDC ] = "0x5ad9c6117ceb1981cfcb89beb6bd29c9157ab5b3";
        cluster.oracleProviders[sUSDe] = "0x475D65970fBa12874caF8660E1aDbAe5dA8567D2";
        cluster.oracleProviders[USDe ] = "0xa436df7c3a77d88d1ec9275b5744bdcc187982f2";
        cluster.oracleProviders[USR  ] = "0xb92b9341be191895e8c68b170ac4528839ffe0b2";
        cluster.oracleProviders[YUSD ] = "0xe5908cbd7b3bc2648b32ce3dc8dfad4d83afd1b4";

        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[USDT ] = 50_000_000;
        cluster.supplyCaps[USDC ] = 50_000_000;
        cluster.supplyCaps[sUSDe] = 50_000_000;
        cluster.supplyCaps[USDe ] = 35_000_000;
        cluster.supplyCaps[USR  ] = 20_000_000;
        cluster.supplyCaps[YUSD ] = 2_000_000;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[USDT ] = 45_000_000;
        cluster.borrowCaps[USDC ] = 45_000_000;
        cluster.borrowCaps[sUSDe] = type(uint256).max;
        cluster.borrowCaps[USDe ] = type(uint256).max;
        cluster.borrowCaps[USR  ] = type(uint256).max;
        cluster.borrowCaps[YUSD ] = type(uint256).max;

        // define IRM classes here and assign them to the assets. if asset is not meant to be borrowable, no IRM is needed.
        // to generate the IRM parameters, use the following command:
        // node lib/evk-periphery/script/utils/calculate-irm-linear-kink.js borrow <baseIr> <kinkIr> <maxIr> <kink>
        {
            // Base=0% APY,  Kink(90%)=9.5% APY  Max=120.00% APY
            uint256[4] memory irm = [uint256(0), uint256(743995130),  uint256(51477290240), uint256(3865470566)];

            cluster.kinkIRMParams[USDT ] = irm;
            cluster.kinkIRMParams[USDC ] = irm;
        }

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 1 days;

        // define the spread between borrow and liquidation LTV
        cluster.spreadLTV = 0.02e4;
    
        // define liquidation LTV values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
        //                0                1        2        3        4        5
        //                USDT             USDC     sUSDe    USDe     USR      YUSD
        /* 0  USDT    */ [uint16(0.000e4), 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4],
        /* 1  USDC    */ [uint16(0.000e4), 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4],
        /* 2  sUSDe   */ [uint16(0.915e4), 0.915e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4],
        /* 3  USDe    */ [uint16(0.925e4), 0.925e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4],
        /* 4  USR     */ [uint16(0.900e4), 0.900e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4],
        /* 5  YUSD    */ [uint16(0.800e4), 0.800e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4]
        ];
    }

    function postOperations() internal view override {
        // verify the oracle config for each vault
        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            OracleVerifier.verifyOracleConfig(lensAddresses.oracleLens, cluster.vaults[i], false);
        }
    }
}
