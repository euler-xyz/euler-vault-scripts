// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {SelfCollateralizationBase} from "./SelfCollateralizationBase.s.sol";

contract SelfCollateralization is SelfCollateralizationBase {
    address internal constant TOKEN = 0xd9Fcd98c322942075A5C3860693e9f4f03AAE07b;
    address internal constant IRM = 0xd7cEEa4b2615A7A8F1da19dC0F92f60D5d4b0BFC;

    function run() public returns (address, address[] memory) {
        return execute(TOKEN, IRM);
    }
}
