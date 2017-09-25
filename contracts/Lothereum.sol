pragma solidity ^0.4.16;

/**
 * @title Lottery Lotthereum
 *
 * Lotthereum is a lottery dapp to finish once
 * and for all the uncertainty arround regular
 * lotteries, it intents to give some
 * of its own profit to charity and a fixed
 * amount to maintainers, developer and ethereum
 * foundation, everyone is welcome to support 1% community
 * soon we gonna have all our rules on Solidity, till there mail us!
 */
contract Lothereum {

    address public constant ETH_TIPJAR = 0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359;
    address public constant ONE_TIPJAR = 0xF6a48CDF83813D26ccaE1Fd00e1af941bc39d121;

    // Meta attributes
    string public name;
    uint8 public blockInterval; // Timelapse between one number drawing
    uint[] public drawingInterval; // Time interval between consecutive drawings (ms)
    uint public drawingIndex; // current index of the drawing interval array
    uint public nextDrawingDate; // timestamp of next drawing date (unix)
    uint32 public drawingCounter; // how many drawings so far
    uint8[] public prizeDistribution; // rules of distribution
    uint16 public maxDrawableNumber; // the highest number starting in 1
    uint8 public minimalHitsForPrize; // first prize at this quantity (problably)
    uint8 public numbersPerTicket; // how many numbers must have in the ticket
    uint public ticketPrice; // exactly the transaction value to get a ticket*/
    uint8[] accumulationRule; // the amnount per drawingId % mod that will be kept to next drawing
    address owner;
    // use openzepelling contract vault
    mapping(address => uint) public vault; // keep winners money

    // Drawing in proccessing
    uint32 public currentProcessIndex;

    // Ticket
    struct Ticket {
        uint16[] numbers;
        address holder;
        uint8 hits;
    }

    // Winning
    struct WinningBets {
        uint prize;
        uint prizeShare;
        uint[] tickets;
    }

    // Events
    event NewTicket(uint32 drawing, address indexed holder, uint ticket, uint16[] numbers);
    event NumberWasDrawed(uint32 drawing, uint16 number);
    event AnnounceDrawing(uint32 drawing, Status status);
    event AnnounceWinner(uint32 drawing, uint ticket, uint8 hits);
    event AnnouncePrize(uint32 indexed drawing, uint8 hits, uint numberOfWinners, uint prizeShare);
    event AnnounceSeed(uint32 drawing, uint seed);
    event AccumulatedPrizeMoved(uint32 fromDrawing, uint total, uint32 toDrawing);
    event PrizeWithdraw(address indexed winner, uint prize);

    // Drawing
    enum Status { Skipped, Running, Drawing, Awarding, Finished }
    struct Drawing {
        Status status;
        uint total;
        mapping(uint8 => WinningBets) winnersPerHit;
        uint[] winningTickets; // tickets jackpot
        uint16[] winningNumbers; // the numbers drawed
        mapping(uint16 => uint[]) numbersMap; // map numbers per ticket
        mapping(uint => Ticket) tickets;
        uint ticketCounter;
        uint feeOnePercent;
        uint donationETHF;
        uint prize;
        uint accumulatedPrizeToMove;
        uint drawingBlock;
    }
    mapping(uint32 => Drawing) public draws;

    // Constructor
    function Lothereum(
        string _name,
        uint[] _drawingInterval,
        uint _firstDrawingDate,
        uint8 _numbersPerTicket,
        uint16 _maxDrawableNumber,
        uint _ticketPrice,
        uint8[] _prizeDistribution,
        uint8 _blockInterval,
        uint8[] _accumulationRule
        ) {
        // validations
        // TODO: transform magic numbers into CONST fgs!
        require(_drawingInterval.length > 0 && _drawingInterval.length < 100);
        for (uint8 j = 0; j < _drawingInterval.length ; j++) {
            require(_drawingInterval[j] >= 60);
        }
        require(_firstDrawingDate > now);
        require(_numbersPerTicket > 0 && _numbersPerTicket < 51);
        require(_maxDrawableNumber > 0 && _maxDrawableNumber < 65535);
        require(_ticketPrice > 0);
        require(_prizeDistribution.length == _numbersPerTicket);
        uint8 prizeDistributionCheck;
        for (uint8 i = 0; i < _prizeDistribution.length ; i++) {
            prizeDistributionCheck += _prizeDistribution[i];
            if (minimalHitsForPrize == 0 && _prizeDistribution[i] != 0) {
                minimalHitsForPrize = i + 1;
            }
        }
        require(prizeDistributionCheck == 100);
        require(_blockInterval > 15 && _blockInterval < 249);
        require(_numbersPerTicket < _maxDrawableNumber); // ex5 numbers with 5 options
        require(_accumulationRule.length == 10);
        for (uint8 k = 0; k < _accumulationRule.length ; k++) {
            require(_accumulationRule[k] <= 90); // must distribute at least 10%
        }
        // effects
        name = _name;
        drawingInterval = _drawingInterval;
        nextDrawingDate = _firstDrawingDate;
        numbersPerTicket = _numbersPerTicket;
        maxDrawableNumber = _maxDrawableNumber;
        ticketPrice = _ticketPrice;
        prizeDistribution = _prizeDistribution;
        blockInterval = _blockInterval;
        accumulationRule = _accumulationRule;

        // initializations
        drawingIndex = 0;
        drawingCounter = 1;
        currentProcessIndex = 1;

        owner = msg.sender;

        _setDrawingStatus(drawingCounter, Status.Running);
    }

    // Announce the new status
    function _setDrawingStatus(uint32 drawingId, Status newStatus) internal {
        draws[drawingId].status = newStatus;
        AnnounceDrawing(drawingId, newStatus);
    }

    // Check the order must be crescent and the max number mustnt be lesser then maxDrawable nubmer
    // TODO: change from constant -> pure
    function _areValidNumbers(uint16[] numbers, uint16 maxNumber) internal constant returns (bool) {
        if (numbers[numbers.length - 1] > maxNumber)
            return false;
        for (uint8 i = 0; i < numbers.length - 1; i++) {
            if (numbers[i] >= numbers[i + 1])
                return false;
        }
        return true;
    }

    // To make the drawing easier
    function _mapTicketNumbers(uint16[] numbers, uint ticketId, uint32 drawingId) internal {
        for (uint8 i = 0; i < numbers.length; i++) {
            draws[drawingId].numbersMap[numbers[i]].push(ticketId);
        }
    }

    // Expose the map of numbers x ticket
    // TODO: change from constant -> view (its for tests only remove to __DEPLOY__)
    function numbersMap(uint32 drawingId, uint16 number) public constant returns (uint[]) {
        return draws[drawingId].numbersMap[number];
    }

    // Is it time to move to next drawing?
    function _nextDrawing() internal {
        // if itsssssss time....!!!!
        if (nextDrawingDate <= now) {
            // freeze data
            uint prizeToMove = draws[drawingCounter].total;
            uint32 drawingId = drawingCounter;
            // if the current drawing has betters (tickets > 0)
            if (draws[drawingCounter].ticketCounter > 0) {
                draws[drawingCounter].drawingBlock = block.number + blockInterval;
                prizeToMove = 0; // reset if it has betters
                _setDrawingStatus(drawingCounter, Status.Drawing); // put it in drawing mode
            } else { // if has not just finish
                _setDrawingStatus(drawingCounter, Status.Skipped); // if has not end it
                // if its skipped here it means that no bets, so we have to transport the prizeToMove
            }
            // if has passed a long time move the lottery ahead skipping till there
            // this gas is on the user but there's nothing we can do about it :D
            while (nextDrawingDate <= now) {
                drawingIndex = (drawingIndex + 1) % drawingInterval.length;
                nextDrawingDate += drawingInterval[drawingIndex];
                drawingCounter++;
                // TODO event to the skips ???
            }
            // move prize (no betters - in case of no winners the prize is moved on result function)
            if (prizeToMove > 0) {
                draws[drawingId].total = 0; // reset
                draws[drawingCounter].total += prizeToMove;
                AccumulatedPrizeMoved(drawingId, prizeToMove, drawingCounter);
            }
            // start new drawing
            _setDrawingStatus(drawingCounter, Status.Running); // if has not end it
        }
    }

    // Drawn the numbers
    function drawNumbers(uint32 drawingId) {
        // process it only if is ready
        if (draws[drawingId].status == Status.Drawing && block.number >= draws[drawingId].drawingBlock) {
            // and the wizard says: THE PAST SHALL NOT CHANGE
            bytes32 seed = block.blockhash(draws[drawingId].drawingBlock);
            uint16[] memory balls = new uint16[](maxDrawableNumber);
            uint16 ballsLen = maxDrawableNumber;
            for (uint16 i = 0; i < balls.length; i++) {
                balls[i] = i + 1;
            }

            while (draws[drawingId].winningNumbers.length < numbersPerTicket) {
                uint16 index = uint16(uint16(keccak256(seed, draws[drawingId].winningNumbers.length)) % (maxDrawableNumber - draws[drawingId].winningNumbers.length));
                draws[drawingId].winningNumbers.push(balls[index]);

                if (index < ballsLen) {
                    for (i = index; i < ballsLen - 1; i++) {
                        balls[i] = balls[i + 1];
                    }
                }
                ballsLen--;
                NumberWasDrawed(drawingId, balls[index]);
            }
            _setDrawingStatus(drawingId, Status.Awarding);
        }
    }

    // Ticket purchase
    function buyTicket(uint16[] numbers) payable {
        // validations
        require(msg.value == ticketPrice);
        require(numbers.length == numbersPerTicket);
        require(_areValidNumbers(numbers, maxDrawableNumber));

        // this drawing is valid or should move the next one
        _nextDrawing();

        // effects
        draws[drawingCounter].ticketCounter += 1; // increment ticket

        // add the new ticket
        draws[drawingCounter].tickets[draws[drawingCounter].ticketCounter] = Ticket({
            numbers: numbers,
            holder: msg.sender,
            hits: 0
        });

        // add value to the total prize
        draws[drawingCounter].total += msg.value;
        _mapTicketNumbers(numbers, draws[drawingCounter].ticketCounter, drawingCounter);

        // actions
        NewTicket(drawingCounter, msg.sender, draws[drawingCounter].ticketCounter, numbers);
    }

    // Contract accept money and add it in the total of current drawing
    function () payable {
        draws[drawingCounter].total += msg.value;
    }

    // Grab your prize !
    function prizeDelivery(address winner) {
        uint amount = vault[winner];
        if (amount > 0) {
            vault[winner] = 0; // set to 0 first so re-entrancy attack wont have anything left to drain.
            winner.transfer(amount);
            PrizeWithdraw(winner, amount);
        }
    }

    // deliver the prize
    function results(uint32 drawingId) {
        // process it only if is ready
        if (draws[drawingId].status == Status.Awarding) {
            uint16 number;
            uint8 hits;
            uint ticketId;
            // search for all tickets that winning something
            for (uint8 i = 0; i < draws[drawingId].winningNumbers.length; i++) {
                // this is all ticket ids that bet in number "winningNumbers[i]"
                number = draws[drawingId].winningNumbers[i];
                for (uint j = 0; j < draws[drawingId].numbersMap[number].length; j++) {
                    ticketId = draws[drawingId].numbersMap[number][j];
                    // save the lottery hits
                    draws[drawingId].tickets[ticketId].hits++;
                     // if hit enough numbers = least numbers to prize add to winners
                    if (draws[drawingId].tickets[ticketId].hits == minimalHitsForPrize) {
                        draws[drawingId].winningTickets.push(ticketId);
                    }
                }
            }

            // map all winining bets per hits
            for (uint w = 0; w < draws[drawingId].winningTickets.length; w++) {
                ticketId = draws[drawingId].winningTickets[w];
                hits = draws[drawingId].tickets[ticketId].hits;
                draws[drawingId].winnersPerHit[hits].tickets.push(ticketId);
                AnnounceWinner(drawingId, ticketId, hits);
             }

            // 1% is our fee and our fee is our name :D
            draws[drawingId].feeOnePercent = draws[drawingId].total / 100;
            // 1% goes to the eth foundation (love ya!)
            draws[drawingId].donationETHF = draws[drawingId].total / 100;
            draws[drawingId].prize = draws[drawingId].total - draws[drawingId].feeOnePercent - draws[drawingId].donationETHF;

            // accumlate to increase some drawing prizes in the future
            draws[drawingId].accumulatedPrizeToMove = (draws[drawingId].prize * accumulationRule[drawingId % 10]) / 100;
            draws[drawingId].prize -= draws[drawingId].accumulatedPrizeToMove;

            vault[ONE_TIPJAR] += draws[drawingId].feeOnePercent;
            vault[ETH_TIPJAR] += draws[drawingId].donationETHF;

            // prize share calculation
            uint amountToMove = draws[drawingId].accumulatedPrizeToMove;
            for (hits = minimalHitsForPrize; hits <= numbersPerTicket; hits++) {
                // no winners for that number of hits **
                draws[drawingId].winnersPerHit[hits].prize = (draws[drawingId].prize * prizeDistribution[hits - 1]) / 100;
                if (draws[drawingId].winnersPerHit[hits].tickets.length > 0) {
                    // we got winners
                    draws[drawingId].winnersPerHit[hits].prizeShare = (draws[drawingId].winnersPerHit[hits].prize / draws[drawingId].winnersPerHit[hits].tickets.length);
                } else {
                    // no winners share = prize
                    draws[drawingId].winnersPerHit[hits].prizeShare = draws[drawingId].winnersPerHit[hits].prize;
                    amountToMove += draws[drawingId].winnersPerHit[hits].prize;
                }
                AnnouncePrize(drawingId, hits, draws[drawingId].winnersPerHit[hits].tickets.length, draws[drawingId].winnersPerHit[hits].prizeShare);
            }

            // move all money without winners (diference) to the current drawing
            if (amountToMove > 0) {
                // current drawing receives it all
                draws[drawingCounter].total += amountToMove;
                AccumulatedPrizeMoved(drawingId, amountToMove, drawingCounter);
            }

            // vault TODO use the Openzepelling stuff
            // deposit all money to the winners
            for (uint v = 0; v < draws[drawingId].winningTickets.length; v++) {
                ticketId = draws[drawingId].winningTickets[v];
                hits = draws[drawingId].tickets[ticketId].hits;
                vault[draws[drawingId].tickets[ticketId].holder] += draws[drawingId].winnersPerHit[hits].prizeShare;
            }

            // set to the payment window status
            _setDrawingStatus(drawingId, Status.Finished);
        }
    }

    // in case of hard bug discovery all ethers go to ETH fundation
    function destroy() {
        require(owner == msg.sender);
        selfdestruct(ETH_TIPJAR);
    }
}
