// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PartnerPrizePool {
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------

    using SafeERC20 for IERC20;

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    enum PartnerPrizePoolErrorCodes {
        CALLER_IS_NOT_LOTTERY
    }

    error PartnerPrizePoolError(PartnerPrizePoolErrorCodes code);

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    /// @dev Emits when the prize sent
    /// @param user User address
    /// @param prizeAmount Prize amount
    event PrizeSent(address indexed user, uint256 prizeAmount);

    /// -----------------------------------------------------------------------
    /// Immutable variables
    /// -----------------------------------------------------------------------

    /// @notice Partner token address
    address public immutable partnerToken;

    /// @notice Lottery contract address
    address public immutable lottery;

    /* ===== INIT ===== */

    /// @dev Constructor function
    /// @param _partnerToken Partner token address
    /// @param _lottery Lottery contract address
    constructor(address _partnerToken, address _lottery) {
        partnerToken = _partnerToken;
        lottery = _lottery;
    }

    /// @notice Function to receive Ether. msg.data must be empty
    receive() external payable {}

    /// @dev Send prize to the winners
    /// @param _user Winner address
    /// @param _prizePercent Prize percent
    /// @return prizeAmount
    function sendPrize(address _user, uint256 _prizePercent)
        external
        returns (uint256)
    {
        if (msg.sender != lottery)
            revert PartnerPrizePoolError(
                PartnerPrizePoolErrorCodes.CALLER_IS_NOT_LOTTERY
            );

        uint256 prizeAmount = (IERC20(partnerToken).balanceOf(address(this)) /
            100) * _prizePercent;

        IERC20(partnerToken).safeTransfer(_user, prizeAmount);

        emit PrizeSent(_user, prizeAmount);

        return prizeAmount;
    }
}
