// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface ILottery {
    /// @dev Complete the lottery.
    /// @dev This method should be called automatically by VRFv2Consumer once chainlink VRF has fullfilled.
    /// @dev We can get lottery id by its request id.
    /// @dev Lottery status should be changed completed so winners can claim the revenue.
    /// @param requestId Request id which get in drawLottery()
    /// @param winRandomNumbers Lottery win random numbers
    function completeLottery(
        uint256 requestId,
        uint256[] memory winRandomNumbers
    ) external;
}
