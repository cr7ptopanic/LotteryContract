// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "./interfaces/ILottery.sol";

contract VRFv2Consumer is VRFConsumerBaseV2 {
    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    enum VRFv2ConsumerErrorCodes {
        CALLER_IS_NOT_LOTTERY
    }

    error VRFv2ConsumerError(VRFv2ConsumerErrorCodes code);

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    /// @dev Emits when random numbers requested
    /// @param requestId Request id
    event RandomWordsRequested(uint256 requestId);

    /// @dev Emits when random numbers arrived
    /// @param randomNumbers Lottery winning numbers
    event RandomWordsArrived(uint256[] randomNumbers);

    /// -----------------------------------------------------------------------
    /// Immutable variables
    /// -----------------------------------------------------------------------

    /// @notice VRF Coordinator
    VRFCoordinatorV2Interface public immutable COORDINATOR;

    /// @notice VRF coordinator address
    address public immutable vrfCoordinator;

    /// @notice Subscription Id
    uint64 public immutable subscriptionId;

    /// @notice Call back gas limit
    /// @dev  Depends on the number of requested values that we want sent to the
    /// @dev  fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    /// @dev  so 150,000 is a safe default for generating 6 random numbers.
    uint32 public immutable callbackGasLimit;

    /// @notice Request confirmations
    uint16 public immutable requestConfirmations;

    /// @notice The gas lane to use, which specifies the maximum gas price to bump to.
    bytes32 public immutable keyHash;

    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------

    /// @notice Random number request Id
    uint256 public requestId;

    /// @notice Lottery address
    address public lottery;

    /// @notice Random numbers count
    uint32 public numWords;

    /* ===== INIT ===== */

    /// @dev Constructor
    /// @param _subscriptionId Subscription Id
    /// @param _vrfCorrdinator VrfCorrdinator contract address
    /// @param _keyHash Key hash
    /// @param _callbackGasLimit Call back gas limit
    /// @param _requestConfirmations Request confirmations
    /// @param _lottery Lottery contract address
    constructor(
        uint64 _subscriptionId,
        address _vrfCorrdinator,
        bytes32 _keyHash,
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations,
        address _lottery
    ) VRFConsumerBaseV2(_vrfCorrdinator) {
        subscriptionId = _subscriptionId;
        vrfCoordinator = _vrfCorrdinator;
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCorrdinator);
        keyHash = _keyHash;
        callbackGasLimit = _callbackGasLimit;
        requestConfirmations = _requestConfirmations;
        lottery = _lottery;
        numWords = 6;
    }

    /// @dev Request random number.
    /// @dev Only lottery can call this method.
    /// @return requestId
    function requestRandomWords() external returns (uint256) {
        if (msg.sender != lottery)
            revert VRFv2ConsumerError(
                VRFv2ConsumerErrorCodes.CALLER_IS_NOT_LOTTERY
            );

        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );

        emit RandomWordsRequested(requestId);

        return requestId;
    }

    /// @dev This function can be called once random numbers have arrived.
    /// @dev After arriving random numbers, we can call lottery with request id and random numbers.
    /// @param _requestId Request id which was generated from requestRandomWords()
    /// @param _randomNumbers Chainlink random numbers
    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomNumbers
    ) internal override {
        uint256[] memory randomNumbers;
        for (uint256 i = 0; i < 6; i++) {
            randomNumbers[i] = (_randomNumbers[i] % 59) + 1;
        }
        ILottery(lottery).completeLottery(_requestId, randomNumbers);

        emit RandomWordsArrived(randomNumbers);
    }
}
