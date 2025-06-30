// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BatchBuilder} from "evk-periphery-scripts/utils/ScriptUtils.s.sol";
import {IEdgeFactory} from "evk-periphery/EdgeFactory/interfaces/IEdgeFactory.sol";

abstract contract SelfCollateralizationBase is BatchBuilder {
    uint16 internal constant BLTV = 0.94e4;
    uint16 internal constant LLTV = 0.95e4;

    function execute(address token, address irm) public returns (address, address[] memory) {
        IEdgeFactory.DeployParams memory params;

        params.vaults = new IEdgeFactory.VaultParams[](2);
        params.vaults[0] = IEdgeFactory.VaultParams({asset: token, irm: address(0), escrow: true});
        params.vaults[1] = IEdgeFactory.VaultParams({asset: token, irm: irm, escrow: false});

        params.router = IEdgeFactory.RouterParams({
            externalResolvedVaults: new address[](0),
            adapters: new IEdgeFactory.AdapterParams[](0)
        });

        params.ltv = new IEdgeFactory.LTVParams[](1);
        params.ltv[0] = IEdgeFactory.LTVParams({
            collateralVaultIndex: 0,
            controllerVaultIndex: 1,
            borrowLTV: BLTV,
            liquidationLTV: LLTV
        });

        params.unitOfAccount = token;

        startBroadcast();
        (address router, address[] memory vaults) = IEdgeFactory(peripheryAddresses.edgeFactory).deploy(params);
        stopBroadcast();

        return (router, vaults);
    }
}
