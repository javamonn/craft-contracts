// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/auth/authorities/RolesAuthority.sol";
import {Authority} from "solmate/auth/Auth.sol";

contract CraftAuthority is RolesAuthority {
    constructor() RolesAuthority(msg.sender, Authority(address(0))) {}
}
