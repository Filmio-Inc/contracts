// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { SafeERC20Upgradeable, IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { ERC2771Recipient } from "@opengsn/contracts/src/ERC2771Recipient.sol";
import { IFilmioProjectV1 } from "../Project/IFilmioProjectV1.sol";
import { VariableDataV1 } from "./VariableDataV1.sol";

contract StakeV1 is ReentrancyGuardUpgradeable, ERC2771Recipient, VariableDataV1 {
    // lock the implementation contract
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // Initialisation section

    function initialize(
        address token,
        address _escrowAccount,
        address _trustedForwarder,
        address _filmioProject
    ) public initializer {
        require(token != address(0), "Invalid token address");
        require(_escrowAccount != address(0), "Invalid escrow account address");
        require(_trustedForwarder != address(0), "Invalid trusted forwarder address");
        require(_filmioProject != address(0), "Invalid filmio project address");

        __ReentrancyGuard_init();
        _setTrustedForwarder(_trustedForwarder);

        tokenInterface = IERC20Upgradeable(token);
        escrowAccount = _escrowAccount;
        filmioProject = _filmioProject;
        stakeIndex = 0;
        totalStakes = 0;
    }

    /**
     * @dev stake FAN tokens on projects/writers etc.
     *
     * @param stakeType stake type.
     * @param projectId type id
     * @param quantity number of tokens
     *
     * Returns
     * - boolean.
     *
     * Emits a {stakeTokens} event.
     */

    function staketokens(
        string memory stakeType,
        string memory projectId,
        uint256 quantity
    ) external nonReentrant returns (bool) {
        require(
            keccak256(abi.encodePacked((stakeType))) == keccak256(abi.encodePacked(("PRJ"))),
            "StakeV1: Invalid stake type"
        );
        require(strlen(projectId) != 0, "StakeV1: Invalid stake project id");
        require(quantity > 0, "StakeV1: Amount should be greater then zero");

        bool doesProjectExist = IFilmioProjectV1(filmioProject).doesProjectExist(projectId);
        require(doesProjectExist, "StakeV1: Given Project Id does not exist");

        stakeIndex += 1; // increment stake index
        Stake memory createdStake = Stake(stakeType, projectId, _msgSender(), stakeIndex, quantity, block.timestamp, 0);

        //check for balance
        require(tokenInterface.balanceOf(_msgSender()) >= quantity, "StakeV1: Insufficient balance in source account");
        //check for allowance
        require(
            tokenInterface.allowance(_msgSender(), address(this)) >= quantity,
            "StakeV1: Source account has not approved stake contract"
        );

        stakes.push(stakeIndex);
        stakeDetails[stakeIndex] = createdStake;

        Stake[] storage stakeOfAccounts = accountStakeDetails[_msgSender()];
        stakeOfAccounts.push(createdStake);

        totalNumberOfAccountStakes[_msgSender()] += quantity;

        Stake[] storage objectStakes = objectStakeDetails[stakeType];
        objectStakes.push(createdStake);
        totalNumberOfObjectStakes[stakeType] = totalNumberOfObjectStakes[stakeType] + quantity;
        totalStakes += quantity;

        stakeIdToIndicies[stakeIndex] = StakeIndicies(objectStakes.length - 1, stakeOfAccounts.length - 1);

        emit StakeTokens(_msgSender(), stakeIndex, quantity, escrowAccount, block.timestamp);

        // Transfers tokens to destination account
        SafeERC20Upgradeable.safeTransferFrom(tokenInterface, _msgSender(), escrowAccount, quantity);

        return true;
    }

    /**
     * @dev unstake FAN tokens on projects/writers etc.
     *
     * @param stakeId stake type.
     * @param quantity number of tokens
     *
     *
     * Returns
     * - boolean.
     *
     * Emits a {unstakeTokens} event.
     */
    function unstaketokens(uint256 stakeId, uint256 quantity) external nonReentrant returns (bool) {
        require(stakeId != 0, "StakeV1: Invalid stake id = 0");

        uint256 indexStakes = stakeId - 1;

        //check if stakeId exists
        require(stakeId <= stakeIndex, "StakeV1: stakeId not found");

        //get details of this stake using stake id
        Stake memory stakedetails = stakeDetails[stakeId];
        require(_msgSender() == stakedetails.account, "StakeV1: Only staker can unstake");
        require(
            stakedetails.quantity >= quantity,
            "StakeV1: Unstake quantity should be less than or equal to staked quantity"
        );
        require(tokenInterface.balanceOf(escrowAccount) >= quantity, "StakeV1: Insufficient balance in escrow account");
        require(
            tokenInterface.allowance(escrowAccount, address(this)) >= quantity,
            "StakeV1: Escrow account has not approved stake contract"
        );

        Stake[] storage objectStakes = objectStakeDetails[stakedetails.stakeType];
        Stake[] storage stakeOfAccounts = accountStakeDetails[stakedetails.account];

        uint256 accountStakeIndex = stakeIdToIndicies[stakeId].accountIndex;
        uint256 objectsStakesIndex = stakeIdToIndicies[stakeId].objectsIndex;

        if (quantity == stakedetails.quantity) {
            //check if all amount is getting unstaked

            if (stakeOfAccounts[accountStakeIndex].stakeId == stakeId) delete stakeOfAccounts[accountStakeIndex];

            if (objectStakes[objectsStakesIndex].stakeId == stakeId) delete objectStakes[objectsStakesIndex];

            delete stakes[indexStakes]; //delete stake id
        }

        stakedetails.quantity = stakedetails.quantity - quantity;
        stakedetails.unstakedTimestamp = block.timestamp;
        stakeDetails[stakeId] = stakedetails; //update the stake record

        if (stakeOfAccounts[accountStakeIndex].stakeId == stakeId)
            stakeOfAccounts[accountStakeIndex].quantity = stakeOfAccounts[accountStakeIndex].quantity - quantity;

        if (objectStakes[objectsStakesIndex].stakeId == stakeId)
            objectStakes[objectsStakesIndex].quantity = objectStakes[objectsStakesIndex].quantity - quantity;

        totalNumberOfAccountStakes[stakedetails.account] = totalNumberOfAccountStakes[stakedetails.account] - quantity;

        totalNumberOfObjectStakes[stakedetails.stakeType] =
            totalNumberOfObjectStakes[stakedetails.stakeType] -
            quantity;

        totalStakes = totalStakes - quantity;

        emit UnstakeTokens(_msgSender(), stakeId, quantity, block.timestamp);

        // Transfers tokens from escrow to staker account
        SafeERC20Upgradeable.safeTransferFrom(tokenInterface, escrowAccount, _msgSender(), quantity);

        return true;
    }

    // This function is used to get the length of a string
    function strlen(string memory s) internal pure returns (uint256) {
        uint256 len;
        uint256 i = 0;
        uint256 byteLength = bytes(s).length;
        for (len = 0; i < byteLength; len++) {
            bytes1 b = bytes(s)[i];
            if (b < 0x80) {
                i += 1;
            } else if (b < 0xE0) {
                i += 2;
            } else if (b < 0xF0) {
                i += 3;
            } else if (b < 0xF8) {
                i += 4;
            } else if (b < 0xFC) {
                i += 5;
            } else {
                i += 6;
            }
        }
        return len;
    }
}
