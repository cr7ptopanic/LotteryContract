// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IVRFv2Consumer {
    /// @dev Request random number.
    /// @dev Only lottery can call this method.
    /// @return requestId
    function requestRandomWords() external returns (uint256);
}
