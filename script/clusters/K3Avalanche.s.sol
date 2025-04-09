// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageClusterBase} from "evk-periphery-scripts/production/ManageClusterBase.s.sol";
import {OracleVerifier} from "evk-periphery-scripts/utils/SanityCheckOracle.s.sol";
import "./Addresses.s.sol";

contract Cluster is ManageClusterBase, AddressesAvalanche {
    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/clusters/K3Avalanche.json";

        // after the cluster is deployed, do not change the order of the assets in the .assets array. if done, it must be 
        // reflected in other the other arrays the ltvs matrix. IMPORTANT: do not define more than one vault for the same asset
        cluster.assets = [USDC, USDT, savUSD, WETH, WAVAX, ggAVAX, sAVAX, BTCb];
    }

    function configureCluster() internal override {
        // define the governors here
        cluster.oracleRoutersGovernor = getDeployer();
        cluster.vaultsGovernor = getDeployer();

        // define unit of account here
        cluster.unitOfAccount = USD;

        // define fee receiver here and interest fee here. 
        // if needed to be defined per asset, populate the feeReceiverOverride and interestFeeOverride mappings
        cluster.feeReceiver = address(0);
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
        cluster.oracleProviders[USDC  ] = "0x997d72fb46690f304C7DB92df9AA823323fb23B2";
        cluster.oracleProviders[USDT  ] = "0xEd29690A4d7f1b63807957fb71149A8dcfD820a4";
        cluster.oracleProviders[savUSD] = "ExternalVault|0xB92B9341be191895e8C68b170aC4528839fFe0b2";
        cluster.oracleProviders[WETH  ] = "0x0505C3f2B1c74ad84f4556a0b5a73386E6286d4E";
        cluster.oracleProviders[WAVAX ] = "0xFaAF6eD6dCD936dA3F4EF105d326D6464529206f";
        cluster.oracleProviders[ggAVAX] = "0x73BF80c6E9812F8Ebc3dc4cBE45247e631d8c44c";
        cluster.oracleProviders[sAVAX ] = "0x74B221fAC3000e94A3618357ddA27d8333f3FC1e";
        cluster.oracleProviders[BTCb  ] = "0xA436dF7C3a77D88D1eC9275B5744BdCC187982f2";

        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[USDC  ] = 10_000_000;
        cluster.supplyCaps[USDT  ] = 10_000_000;
        cluster.supplyCaps[savUSD] = 1_000_000;
        cluster.supplyCaps[WETH  ] = 3_000;
        cluster.supplyCaps[WAVAX ] = 1_000_000;
        cluster.supplyCaps[ggAVAX] = 250_000;
        cluster.supplyCaps[sAVAX ] = 150_000;
        cluster.supplyCaps[BTCb  ] = 100;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[USDC  ] = 9_000_000;
        cluster.borrowCaps[USDT  ] = 9_000_000;
        cluster.borrowCaps[savUSD] = type(uint256).max;
        cluster.borrowCaps[WETH  ] = 2_550;
        cluster.borrowCaps[WAVAX ] = 850_000;
        cluster.borrowCaps[ggAVAX] = type(uint256).max;
        cluster.borrowCaps[sAVAX ] = type(uint256).max;
        cluster.borrowCaps[BTCb  ] = 85;

        // define IRM classes here and assign them to the assets. if asset is not meant to be borrowable, no IRM is needed.
        // to generate the IRM parameters, use the following command:
        // node lib/evk-periphery/script/utils/calculate-irm-linear-kink.js borrow <baseIr> <kinkIr> <maxIr> <kink>
        {
            // Base=0% APY,  Kink(90%)=12.00% APY  Max=120.00% APY
            uint256[4] memory irmUSD    = [uint256(0), uint256(929057149),  uint256(49811732071), uint256(3865470566)];
            
            // Base=0% APY  Kink(85%)=5.00% APY  Max=80.00% APY
            uint256[4] memory irmETH    = [uint256(0), uint256(423504902),  uint256(26511834202), uint256(3650722201)];

            // Base=0% APY  Kink(85%)=9.00% APY  Max=90.00% APY
            uint256[4] memory irmAVAX   = [uint256(0), uint256(748033491),  uint256(27332264717), uint256(3650722201)];

            // Base=0% APY  Kink(85%)=3.50% APY  Max=80.00% APY
            uint256[4] memory irmBTC    = [uint256(0), uint256(298608804),  uint256(27219578754), uint256(3650722201)];

            cluster.kinkIRMParams[USDC  ] = irmUSD;
            cluster.kinkIRMParams[USDT  ] = irmUSD;
            cluster.kinkIRMParams[WETH  ] = irmETH;
            cluster.kinkIRMParams[WAVAX ] = irmAVAX;
            cluster.kinkIRMParams[BTCb  ] = irmBTC;
        }

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 1 days;

        // define the spread between borrow and liquidation LTV
        cluster.spreadLTV = 0.02e4;
    
        // define liquidation LTV values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
        //                0               1       2       3       4       5       6       7
        //                USDC            USDT    savUSD  WETH    WAVAX   ggAVAX  sAVAX   BTCb
        /* 0  USDC    */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.85e4, 0.82e4, 0.00e4, 0.00e4, 0.75e4],
        /* 1  USDT    */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.85e4, 0.82e4, 0.00e4, 0.00e4, 0.75e4],
        /* 2  savUSD  */ [uint16(0.90e4), 0.90e4, 0.00e4, 0.85e4, 0.82e4, 0.00e4, 0.00e4, 0.75e4],
        /* 3  WETH    */ [uint16(0.85e4), 0.85e4, 0.00e4, 0.00e4, 0.82e4, 0.00e4, 0.00e4, 0.75e4],
        /* 4  WAVAX   */ [uint16(0.82e4), 0.82e4, 0.00e4, 0.82e4, 0.00e4, 0.00e4, 0.00e4, 0.75e4],
        /* 5  ggAVA   */ [uint16(0.75e4), 0.75e4, 0.00e4, 0.75e4, 0.75e4, 0.00e4, 0.00e4, 0.75e4],
        /* 6  sAVAX   */ [uint16(0.75e4), 0.75e4, 0.00e4, 0.75e4, 0.75e4, 0.00e4, 0.00e4, 0.75e4],
        /* 7  BTCb    */ [uint16(0.75e4), 0.75e4, 0.00e4, 0.75e4, 0.75e4, 0.00e4, 0.00e4, 0.00e4]
        ];
    }

    function postOperations() internal view override {
        // verify the oracle config for each vault
        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            OracleVerifier.verifyOracleConfig(lensAddresses.oracleLens, cluster.vaults[i], false);
        }
    }
}
