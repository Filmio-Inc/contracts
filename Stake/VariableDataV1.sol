pragma solidity ^0.8.9;
// SPDX-License-Identifier: MIT

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract VariableDataV1 {
    // struct details for staking
    struct Stake {
        string stakeType;
        string typeId;
        address account;
        uint256 stakeId;
        uint256 quantity;
        uint256 stakedTimestamp;
        uint256 unstakedTimestamp;
    }

    struct StakeIndicies {
        uint256 objectsIndex;
        uint256 accountIndex;
    }

    // mapping of stake Id with stake details
    mapping(uint256 => Stake) public stakeDetails;

    // mapping of user address with stake array
    mapping(address => Stake[]) public accountStakeDetails;

    // mapping of stake Id with its owner
    mapping(uint256 => StakeIndicies) public stakeIdToIndicies;

    // mapping of stake type with stake array
    mapping(string => Stake[]) public objectStakeDetails;

    // mapping of address w.r.t its total stake amount
    mapping(address => uint256) public totalNumberOfAccountStakes;

    // mapping of stake type w.r.t its stake amount
    mapping(string => uint256) public totalNumberOfObjectStakes;

    // array of stake Id
    uint256[] public stakes;

    // stake Index
    uint256 public stakeIndex;

    // total stake amount
    uint256 public totalStakes;

    // FAN Token Interface
    IERC20Upgradeable internal tokenInterface;

    address public filmioProject;

    // address of escrow account
    address public escrowAccount;

    event StakeTokens(address indexed user, uint256 indexed stakeId, uint256 amount, address to, uint256 timestamp);

    event UnstakeTokens(address indexed user, uint256 indexed stakeId, uint256 quantity, uint256 timestamp);
}
