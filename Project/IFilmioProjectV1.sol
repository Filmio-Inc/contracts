pragma solidity ^0.8.9;

// SPDX-License-Identifier: MIT

interface IFilmioProjectV1 {
    function doesProjectExist(string memory projectId) external view returns (bool);
}
