// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./FanERC20TokenV1.sol";

contract FanTokenV2 is FanTokenV1 {
    function v2() public pure returns (string memory) {
        return "v2";
    }
}
