// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IPartnerPrizePool {
    /// @dev Send prize to the winners
    /// @param _user Winner address
    /// @param _prizePercent Prize percent
    /// @return prizeAmount
    function sendPrize(address _user, uint256 _prizePercent)
        external
        returns (uint256);
}
