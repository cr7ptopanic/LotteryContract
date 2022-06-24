// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IAggregator {
    /// @dev Get latest price
    function getLatestPrice() external view returns (int256);
}
