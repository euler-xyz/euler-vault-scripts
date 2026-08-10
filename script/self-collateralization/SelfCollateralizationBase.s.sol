// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BatchBuilder} from "evk-periphery-scripts/utils/ScriptUtils.s.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {EulerRouter} from "euler-price-oracle/EulerRouter.sol";
import {IEulerRouterFactory} from "evk-periphery/EulerRouterFactory/interfaces/IEulerRouterFactory.sol";
import {EscrowedCollateralPerspective} from "evk-periphery/Perspectives/deployed/EscrowedCollateralPerspective.sol";

/// @dev Deploys a two-vault self-collateralized market: an escrowed collateral vault and a
/// borrowable vault on the same asset, priced 1:1 through a governance-renounced router.
/// Replicates the deployment flow of the deprecated EdgeFactory without relying on it.
abstract contract SelfCollateralizationBase is BatchBuilder {
    uint16 internal constant BLTV = 0.94e4;
    uint16 internal constant LLTV = 0.95e4;
    uint16 internal constant LIQ_COOL_OFF_TIME = 1;
    uint16 internal constant MAX_LIQ_DISCOUNT = 0.15e4;

    function execute(address token, address irm) public returns (address, address[] memory) {
        startBroadcast();

        // Deploy the oracle router, governed by the deployer until configured
        EulerRouter router =
            EulerRouter(IEulerRouterFactory(peripheryAddresses.oracleRouterFactory).deploy(getDeployer()));

        address[] memory vaults = new address[](2);

        // Escrow collateral vault: reuse the escrowed collateral perspective singleton if one
        // already exists for the asset, otherwise deploy and verify it in the perspective
        EscrowedCollateralPerspective escrowedCollateralPerspective =
            EscrowedCollateralPerspective(peripheryAddresses.escrowedCollateralPerspective);
        vaults[0] = escrowedCollateralPerspective.singletonLookup(token);
        if (vaults[0] == address(0)) {
            vaults[0] = GenericFactory(coreAddresses.eVaultFactory).createProxy(
                address(0), true, abi.encodePacked(token, address(0), address(0))
            );
            IEVault(vaults[0]).setHookConfig(address(0), 0);
            IEVault(vaults[0]).setGovernorAdmin(address(0));
            escrowedCollateralPerspective.perspectiveVerify(vaults[0], true);
        }

        // Borrowable vault, using the token itself as the unit of account
        vaults[1] = GenericFactory(coreAddresses.eVaultFactory).createProxy(
            address(0), true, abi.encodePacked(token, address(router), token)
        );
        IEVault(vaults[1]).setInterestRateModel(irm);
        IEVault(vaults[1]).setLiquidationCoolOffTime(LIQ_COOL_OFF_TIME);
        IEVault(vaults[1]).setMaxLiquidationDiscount(MAX_LIQ_DISCOUNT);
        IEVault(vaults[1]).setHookConfig(address(0), 0);

        // Resolve both vaults in the router and renounce its governance
        router.govSetResolvedVault(vaults[0], true);
        router.govSetResolvedVault(vaults[1], true);
        router.transferGovernance(address(0));

        // Accept the escrow vault as collateral and renounce vault governance
        IEVault(vaults[1]).setLTV(vaults[0], BLTV, LLTV, 0);
        IEVault(vaults[1]).setGovernorAdmin(address(0));

        stopBroadcast();

        return (address(router), vaults);
    }
}
