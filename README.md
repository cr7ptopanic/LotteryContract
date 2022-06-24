# LotteryContract

## Requirements
Task: Write smart contracts for the following problem statement
A lottery is supposed to be held and following are the terms and conditions to be
followed throughout the process.
Division of Prize Among Winners: The Prize payout shall be determined on a pari-mutuel
basis.
To play Lottery, the player should fill in the interactive play slip on the website.
Choose six main numbers ranging from 1 to 59
Each Lottery has a total of 5 prize tiers.
Prizes can be won by matching two or more numbers
Random winning number generator using Chainlink oracle is to be used.
-65% of each partner lottery revenue will be available to be paid out in Prizes
Prize Tier for each lottery
Match 6 30% (Jackpot)
Match 5 10%
Match 4 10%
Match 3 15%
Match 2 35%
Draws take place at 21:00 UTC on Wednesdays and Saturdays.
Ticket sales for each draw close 30 minutes earlier at 20:30 UTC
The player wins the jackpot by correctly matching all six numbers drawn.
The cost of the ticket is to be determined, but for this example let’s consider that it
costs 5 $ (for example this can be adjusted)
The cost of the ticket is pegged to usd and can be bought with a $partner token,
$mytoken or $BNB
The player that wants to play the lottery needs to hold a determined amount of the
partner token or of $mytoken.
Example :
Marc created a coin called “Safemoon” and John is a “Safemoon” holder.
Marc wants to create a lottery Dapp and use our Lottery Builder for that.
The cost to create a lottery for Marc is: 1BNB to be paid to $mytoken Team.
The cost to participate in the lottery for John is the ticket he buys with Safemoon token
Every time John spends SAFEMOON to buy a ticket of the SAFEMOON lottery
65% goes to the SAFEMOON prize pool
10% goes to the SAFEMOON liquidity pool
10% goes to the SAFEMOON staking pool
10% goes to SAFEMOON team wallet
5% goes to mytoken team wallet

## Developement
### Lottery
- Create Lottery
- Buy tickets with BNB or mytoken or partnertoken
- Draw lottery which close the specific lottery by requesting lottery winning numbers
- Complete lottery after arriving random numbers from chainlink VRF
- Claim tokens by users after completing the lottery.

### PartnerPrizePool
- 65% of each partner lottery revenue should go this pool
- Send the funds to the winners from this pool.
### VRFv2Consumer
Chainlink VRFv2Consumer for generating random numbers.

### DateTime Library
Library for calculating the weekday and hour for a given time.

## Every methods have their comments for your understanding.