// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IVRFv2Consumer.sol";
import "./interfaces/IPartnerPrizePool.sol";
import "./interfaces/IAggregator.sol";
import "../library/DateTime.sol";

contract Lottery is ReentrancyGuard {
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------

    using SafeERC20 for IERC20;

    /// -----------------------------------------------------------------------
    /// Struct
    /// -----------------------------------------------------------------------

    /// @param winNumbers Winning numbers
    /// @param partnerToken Partner token address
    /// @param partnerTokenUSD Partner token/USD price contract address
    /// @param partnerPrizePool PartnerPrizePool address
    /// @param partnerLiquidityPool PartnerLiquidityPool address
    /// @param partnerStakingPool PartnerStakingePool address
    /// @param partnerTeamWallet PartnerTeamWallet address
    /// @param lotteryStatus Lottery status
    struct LotteryInfo {
        uint256[] winNumbers;
        address partnerToken;
        address partnerTokenUSD;
        address partnerPrizePool;
        address partnerLiquidityPool;
        address partnerStakingPool;
        address partnerTeamWallet;
        Status lotteryStatus;
    }

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    enum LotteryErrorCodes {
        INSUFFICIENT_BALANCE,
        LOTTERY_NOT_OPEN,
        NOT_TIME_TO_BUY,
        NOT_TIME_TO_DRAW,
        FAILED_TO_SEND_ETH,
        NOT_RNG_ADDRESS,
        LOTTERY_NOT_CLOSED,
        REWARD_ALREADY_CLAIMED,
        LOTTERY_NOT_COMPLETED,
        INVALID_TICKET_NUMBER,
        TICKET_ALREADY_PURCHASED,
        NO_PRIZE,
        INVALID_TICKET
    }

    error LotteryError(LotteryErrorCodes code);

    /// -----------------------------------------------------------------------
    /// Enum variables
    /// -----------------------------------------------------------------------

    enum Status {
        Open, // The lottery is open for ticket purchases
        Closed, // The lottery is no longer open for ticket purchases
        Completed // The lottery has been closed and the numbers drawn
    }

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    /// @dev Emits when user created lottery.
    /// @param lotteryId Lottery id
    /// @param lotteryFee Lottery creating fee
    event LotteryCreated(uint256 lotteryId, uint256 lotteryFee);

    /// @dev Emits when user bought the ticket with bet20 token.
    /// @param lotteryId Lottery id
    /// @param ticket 6 user numbers array
    /// @param buyType Wheather myToken or partnerToken
    event TicketBoughtWithBep20(
        uint256 lotteryId,
        uint256[] ticket,
        bool buyType
    );

    /// @dev Emits when user bought the ticket with BNB.
    /// @param lotteryId Lottery id
    /// @param ticket 6 user numbers array
    event TicketBoughtWithBNB(uint256 lotteryId, uint256[] ticket);

    /// @dev Emits when lottery has drawn.
    /// @param lotteryId Lottery id
    /// @param requestId VRF request id
    event LotteryDrew(uint256 lotteryId, uint256 requestId);

    /// @dev Emits when lottery has completed
    /// @param lotteryId Lottery id
    /// @param winRandomNumbers Lottery winning numbers
    event LotteryCompleted(uint256 lotteryId, uint256[] winRandomNumbers);

    /// @dev Emits when user claimed the prize.
    /// @param user Winner address
    /// @param totalPercent Total percent
    /// @param prizeAmount Prize amount
    event PrizesClaimed(
        address indexed user,
        uint256 totalPercent,
        uint256 prizeAmount
    );
    /// -----------------------------------------------------------------------
    /// Immutable variables
    /// -----------------------------------------------------------------------

    /// @notice myToken address
    address public immutable myToken;

    /// @notice Chainlink VRFv2Consumer address
    address public immutable VRFv2Consumer;

    /// @notice myToken Team wallet address
    address public immutable myTokenTeamWallet;

    /// @notice myToken/USD price contract address
    address public immutable myTokenUSD;

    /// @notice Cost per ticket
    uint256 public immutable costPerTicket;

    /// @notice Creating lottery fee
    uint256 public immutable lotteryFee;

    /// -----------------------------------------------------------------------
    /// Constant variables
    /// -----------------------------------------------------------------------

    /// @notice BNB/USD price contract address
    address public constant BNBUSD = 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE;

    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------

    /// @notice Latest lottery id
    uint256 public currentLotteryId;

    /// @notice Prize percent array
    /// @dev 0 matched - 0 %, 1 - 0 %, 2 - 35 %
    /// @dev 3 matched - 15 %, 4 - 10 %, 5 - 10 %
    /// @dev 6 matched(Jackpot) - 30 %
    uint256[7] public prizePercent = [0, 0, 35, 15, 10, 10, 30];

    /// @notice Mapping of lottery list
    mapping(uint256 => LotteryInfo) public lotteryList;

    /// @notice List of tickets the player owns
    mapping(uint256 => mapping(address => uint256[][])) public userTickets;

    /// @notice If the player's tickets have been paid out yet
    mapping(uint256 => mapping(address => bool)) public rewardsClaimed;

    /// @notice If the ticket already purchased
    /// @dev Compared with one number, not compared each number using loop statement.
    /// @dev If user's ticket numbers are 10, 21, 5, 11, 6, 9
    /// @dev It can be represented with one number with z = x* 100 + y formula
    /// @dev Ex: 10 * 100 + 21 = 1021, 1021 * 100 + 5 = 102105 ...
    mapping(uint256 => mapping(uint256 => bool)) public ticketPurchased;

    /// @notice Lottery id by request id
    mapping(uint256 => uint256) public lotteryIdByRequestId;

    /// -----------------------------------------------------------------------
    /// Modifiers
    /// -----------------------------------------------------------------------

    modifier isTimeTobuy() {
        if (
            DateTime.getWeekday(block.timestamp) == 2 ||
            DateTime.getWeekday(block.timestamp) == 5
        ) {
            if (
                DateTime.getHour(block.timestamp) >= 21 ||
                (DateTime.getHour(block.timestamp) == 20 &&
                    DateTime.getMinute(block.timestamp) >= 30)
            ) {
                revert LotteryError(LotteryErrorCodes.NOT_TIME_TO_BUY);
            }
        }
        _;
    }

    modifier isTimeToDraw() {
        if (
            DateTime.getWeekday(block.timestamp) != 2 &&
            DateTime.getWeekday(block.timestamp) != 5
        ) {
            revert LotteryError(LotteryErrorCodes.NOT_TIME_TO_DRAW);
        }

        if (DateTime.getHour(block.timestamp) != 21) {
            revert LotteryError(LotteryErrorCodes.NOT_TIME_TO_DRAW);
        }

        _;
    }

    modifier isLotteryOpen(uint256 _lotteryId) {
        if (lotteryList[_lotteryId].lotteryStatus == Status.Open)
            revert LotteryError(LotteryErrorCodes.LOTTERY_NOT_OPEN);
        _;
    }

    modifier isTicketCorrect(uint256 _ticketLength) {
        if (_ticketLength > 6) {
            revert LotteryError(LotteryErrorCodes.INVALID_TICKET);
        }
        _;
    }

    /* ===== INIT ===== */

    /// @dev Constructor function
    /// @param _myToken myToken address
    /// @param _VRFv2Consumer Chainlink VRFv2Consumer contract address
    /// @param _myTokenTeamWallet myToken team wallet address
    /// @param _myTokenUSD myToken/USD price contract address
    /// @param _lotteryFee Creating lottery fee
    /// @param _costPerTicket Ticket price
    constructor(
        address _myToken,
        address _VRFv2Consumer,
        address _myTokenTeamWallet,
        address _myTokenUSD,
        uint256 _lotteryFee,
        uint256 _costPerTicket
    ) {
        myToken = _myToken;
        VRFv2Consumer = _VRFv2Consumer;
        myTokenTeamWallet = _myTokenTeamWallet;
        myTokenUSD = _myTokenUSD;
        lotteryFee = _lotteryFee;
        costPerTicket = _costPerTicket;
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    /// -----------------------------------------------------------------------
    /// Partner actions
    /// -----------------------------------------------------------------------

    /// @dev Create lottery.
    /// @dev Users can create lottery by paying lotteryFee with BNB.
    /// @dev That lotteryFee(BNB) should send to our team wallet.
    /// @param _partnerToken Partner token address
    /// @param _partnerTokenUSD Partner token/USD price contract address
    /// @param _partnerPrizePool PartnerPrizePool address
    /// @param _partnerLiquidityPool PartnerLiquidityPool address
    /// @param _partnerStakingPool PartnerStakingePool address
    /// @param _partnerTeamWallet PartnerTeamWallet address
    function createLottery(
        address _partnerToken,
        address _partnerTokenUSD,
        address _partnerPrizePool,
        address _partnerLiquidityPool,
        address _partnerStakingPool,
        address _partnerTeamWallet
    ) external payable nonReentrant {
        if (msg.value < lotteryFee)
            revert LotteryError(LotteryErrorCodes.INSUFFICIENT_BALANCE);

        (bool success, ) = payable(myTokenTeamWallet).call{value: msg.value}(
            ""
        );
        if (success == false)
            revert LotteryError(LotteryErrorCodes.FAILED_TO_SEND_ETH);

        LotteryInfo storage lotteryInfo = lotteryList[currentLotteryId];

        lotteryInfo.partnerToken = _partnerToken;
        lotteryInfo.partnerTokenUSD = _partnerTokenUSD;
        lotteryInfo.partnerPrizePool = _partnerPrizePool;
        lotteryInfo.partnerLiquidityPool = _partnerLiquidityPool;
        lotteryInfo.partnerStakingPool = _partnerStakingPool;
        lotteryInfo.partnerTeamWallet = _partnerTeamWallet;
        lotteryInfo.lotteryStatus = Status.Open;

        currentLotteryId++;

        emit LotteryCreated(currentLotteryId - 1, lotteryFee);
    }

    /// -----------------------------------------------------------------------
    /// User actions
    /// -----------------------------------------------------------------------

    /// @dev Buy tickets with partneToken or myToken
    /// @dev Use chainlink price oracle for getting token price.
    /// @param _lotteryId Lottery id
    /// @param _ticket 6 numbers in the ticket which users chose
    /// @param _buyType Wheather myToken or partnerToken
    function buyTicketWithBep20(
        uint256 _lotteryId,
        uint256[] memory _ticket,
        bool _buyType
    )
        external
        isTicketCorrect(_ticket.length)
        isTimeTobuy
        isLotteryOpen(_lotteryId)
        nonReentrant
    {
        LotteryInfo storage lottery = lotteryList[_lotteryId];

        address token;
        uint256 tokenPrice;

        if (_buyType == true) {
            token = myToken;
            tokenPrice = myTokenLatestPrice();
        } else {
            token = lottery.partnerToken;
            tokenPrice = partnerTokenLatestPrice(lottery.partnerTokenUSD);
        }

        uint256 ticketNumber = checkTicketNumber(_lotteryId, _ticket);

        if (IERC20(token).balanceOf(msg.sender) < tokenPrice * costPerTicket)
            revert LotteryError(LotteryErrorCodes.INSUFFICIENT_BALANCE);

        IERC20(token).safeTransferFrom(
            msg.sender,
            lottery.partnerPrizePool,
            (tokenPrice * costPerTicket * 65) / 100
        );
        IERC20(token).safeTransferFrom(
            msg.sender,
            lottery.partnerLiquidityPool,
            (tokenPrice * costPerTicket) / 10
        );
        IERC20(token).safeTransferFrom(
            msg.sender,
            lottery.partnerStakingPool,
            (tokenPrice * costPerTicket) / 10
        );
        IERC20(token).safeTransferFrom(
            msg.sender,
            lottery.partnerTeamWallet,
            (tokenPrice * costPerTicket) / 10
        );
        IERC20(token).safeTransferFrom(
            msg.sender,
            myTokenTeamWallet,
            (tokenPrice * costPerTicket) / 20
        );

        userTickets[_lotteryId][msg.sender].push(_ticket);

        ticketPurchased[_lotteryId][ticketNumber] = true;

        emit TicketBoughtWithBep20(_lotteryId, _ticket, _buyType);
    }

    /// @dev Buy tickets with BNB
    /// @dev Use chainlink price oracle for getting BNB/USD price.
    /// @param _lotteryId Lottery id
    /// @param _ticket 6 numbers in ticket which users choose
    function buyTicketWithBNB(uint256 _lotteryId, uint256[] memory _ticket)
        external
        payable
        isTicketCorrect(_ticket.length)
        isTimeTobuy
        isLotteryOpen(_lotteryId)
        nonReentrant
    {
        LotteryInfo storage lottery = lotteryList[_lotteryId];

        uint256 ticketNumber = checkTicketNumber(_lotteryId, _ticket);

        if (msg.value < BNBLatestPrice() * costPerTicket)
            revert LotteryError(LotteryErrorCodes.INSUFFICIENT_BALANCE);

        bool success;

        (success, ) = payable(lottery.partnerPrizePool).call{
            value: (BNBLatestPrice() * costPerTicket * 65) / 100
        }("");
        if (success == false)
            revert LotteryError(LotteryErrorCodes.FAILED_TO_SEND_ETH);

        (success, ) = payable(lottery.partnerLiquidityPool).call{
            value: (BNBLatestPrice() * costPerTicket) / 10
        }("");
        if (success == false)
            revert LotteryError(LotteryErrorCodes.FAILED_TO_SEND_ETH);

        (success, ) = payable(lottery.partnerStakingPool).call{
            value: (BNBLatestPrice() * costPerTicket) / 10
        }("");
        if (success == false)
            revert LotteryError(LotteryErrorCodes.FAILED_TO_SEND_ETH);

        (success, ) = payable(lottery.partnerTeamWallet).call{
            value: (BNBLatestPrice() * costPerTicket) / 10
        }("");
        if (success == false)
            revert LotteryError(LotteryErrorCodes.FAILED_TO_SEND_ETH);

        (success, ) = payable(myTokenTeamWallet).call{
            value: (BNBLatestPrice() * costPerTicket) / 20
        }("");
        if (success == false)
            revert LotteryError(LotteryErrorCodes.FAILED_TO_SEND_ETH);

        userTickets[_lotteryId][msg.sender].push(_ticket);

        ticketPurchased[_lotteryId][ticketNumber] = true;

        emit TicketBoughtWithBNB(_lotteryId, _ticket);
    }

    /// @dev Claim prizes
    /// @dev Users can claim prizes after lottery has completed only.
    /// @dev PartnerPrizePool should send the prizes to the winners.
    /// @param _lotteryId Lottery id
    function claimPrizes(uint256 _lotteryId) external nonReentrant {
        if (rewardsClaimed[_lotteryId][msg.sender] == true)
            revert LotteryError(LotteryErrorCodes.REWARD_ALREADY_CLAIMED);

        LotteryInfo memory lottery = lotteryList[_lotteryId];

        if (lottery.lotteryStatus != Status.Completed)
            revert LotteryError(LotteryErrorCodes.LOTTERY_NOT_COMPLETED);

        uint256 totalPercent;

        for (
            uint256 i = 0;
            i < userTickets[_lotteryId][msg.sender].length;
            i++
        ) {
            totalPercent += getPercentPerTicket(
                userTickets[_lotteryId][msg.sender][i],
                lottery.winNumbers
            );
        }

        if (totalPercent == 0) revert LotteryError(LotteryErrorCodes.NO_PRIZE);

        uint256 prizeAmount = IPartnerPrizePool(lottery.partnerPrizePool)
            .sendPrize(msg.sender, totalPercent);

        rewardsClaimed[_lotteryId][msg.sender] = true;

        emit PrizesClaimed(msg.sender, totalPercent, prizeAmount);
    }

    /// @dev Draw lottery
    /// @dev Anyone can draw the lottery if the time is correct.
    /// @dev Prefer to use the backend time bot to run this method.
    /// @dev Request game random numbers from Chainlink VRFv2.
    /// @dev Lottery status should be changed closed so users can't buy the tickets.
    /// @param _lotteryId Lottery id
    function drawLottery(uint256 _lotteryId)
        external
        isTimeToDraw
        nonReentrant
    {
        lotteryList[_lotteryId].lotteryStatus = Status.Closed;

        uint256 requestId = IVRFv2Consumer(VRFv2Consumer).requestRandomWords();
        lotteryIdByRequestId[requestId] = _lotteryId;

        emit LotteryDrew(_lotteryId, requestId);
    }

    /// -----------------------------------------------------------------------
    /// VRFv2Comsumer actions
    /// -----------------------------------------------------------------------

    /// @dev Complete the lottery.
    /// @dev This method should be called automatically by VRFv2Consumer once chainlink VRF has fullfilled.
    /// @dev We can get lottery id by its request id.
    /// @dev Lottery status should be changed completed so winners can claim the revenue.
    /// @param _requestId Request id which get in drawLottery()
    /// @param _winRandomNumbers Lottery win random numbers
    function completeLottery(
        uint256 _requestId,
        uint256[] memory _winRandomNumbers
    ) external nonReentrant {
        if (msg.sender != VRFv2Consumer)
            revert LotteryError(LotteryErrorCodes.NOT_RNG_ADDRESS);

        uint256 lotteryId = lotteryIdByRequestId[_requestId];

        LotteryInfo storage lottery = lotteryList[lotteryId];

        if (lottery.lotteryStatus != Status.Closed)
            revert LotteryError(LotteryErrorCodes.LOTTERY_NOT_CLOSED);

        lottery.winNumbers = _winRandomNumbers;
        lottery.lotteryStatus = Status.Completed;

        emit LotteryCompleted(lotteryId, _winRandomNumbers);
    }

    /// -----------------------------------------------------------------------
    /// Internal methods
    /// -----------------------------------------------------------------------

    /// @dev Get the partnerToken/USD price.
    /// @param _partnerTokenUSD partnerToken/USD price contract address
    /// @return latestPrice
    function partnerTokenLatestPrice(address _partnerTokenUSD)
        internal
        view
        returns (uint256)
    {
        return uint256(IAggregator(_partnerTokenUSD).getLatestPrice());
    }

    /// @dev Get the myToken/USD price.
    /// @return latestPrice
    function myTokenLatestPrice() internal view returns (uint256) {
        return uint256(IAggregator(myTokenUSD).getLatestPrice());
    }

    /// @dev Get the BNB/USD price.
    /// @return latestPrice
    function BNBLatestPrice() internal view returns (uint256) {
        return uint256(IAggregator(BNBUSD).getLatestPrice());
    }

    /// @dev Check the numbers of ticket if the ticket is already purchased or ticket numbers are all valid.
    /// @dev Make 6 numbers to one number for checking.
    /// @param _lotteryId Lottery id
    /// @param _ticket Numbers of ticket
    /// @return number
    function checkTicketNumber(uint256 _lotteryId, uint256[] memory _ticket)
        internal
        view
        returns (uint256)
    {
        uint256 ticketNumber;

        if (ticketPurchased[_lotteryId][ticketNumber] == true) {
            revert LotteryError(LotteryErrorCodes.TICKET_ALREADY_PURCHASED);
        }

        for (uint256 i = 0; i < 6; i++) {
            if (_ticket[i] == 0 || _ticket[i] >= 60) {
                revert LotteryError(LotteryErrorCodes.INVALID_TICKET_NUMBER);
            }
            ticketNumber = ticketNumber * 100 + _ticket[i];
        }

        return ticketNumber;
    }

    /// @dev Get percent per ticket by calculating the matches.
    /// @param _userNumbers User numbers
    /// @param _winNumbers Lotter winning numbers
    /// @return prizePercent
    function getPercentPerTicket(
        uint256[] memory _userNumbers,
        uint256[] memory _winNumbers
    ) internal view returns (uint256) {
        uint256 countMatched;

        for (uint256 i = 0; i < 6; i++) {
            if (_userNumbers[i] == _winNumbers[i]) {
                countMatched++;
            }
        }

        return prizePercent[countMatched];
    }
}
