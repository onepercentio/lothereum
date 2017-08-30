pragma solidity ^0.4.13;

/**
 * @title Lottery Lotthereum
 *
 * Lotthereum is a lottery dapp to finish once
 * and for all the uncertainty arround regular
 * lotteries, it intents to give some
 * of its own profit to charity and a fixed
 * amount to maintainers, developer and ethereum
 * foundation, every one is welcome to support 1% community
 * soon we gonna have all our rules on Solidity, till there mail us!
 */
contract Lothereum {

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
    // use openzepelling contract vault
    mapping(address => uint) public vault; // keep winners money

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

    // Drawing seed generator
    uint32 seedCounter;

    // Events
    event NewTicket(uint32 drawing, address holder, uint ticket, uint16[] numbers);
    event NumberWasDrawed(uint32 drawing, uint16 number);
    event AnnounceDrawing(uint32 drawing, Status status);
    event AnnounceWinner(uint32 drawing, uint ticket, uint8 hits);
    event AnnouncePrize(uint32 drawing, uint8 hits, uint numberOfWinners, uint prizeShare);
    event AccumulatedPrizeMoved(uint32 fromDrawing, uint total, uint32 toDrawing);

    // Drawing
    enum Status { Skipped, Running, Drawing, Drawn, Awarding, Finished }
    struct Drawing {
        Status status;
        uint totalPrize;
        mapping(uint8 => WinningBets) winnersPerHit;
        uint[] winningTickets; // tickets jackpot
        uint16[] winningNumbers; // the numbers drawed
        mapping(uint16 => uint[]) numbersMap; // map numbers per ticket
        mapping(uint => Ticket) tickets;
        uint ticketCounter;
        uint nextBlockNumber;
        bytes32[] seeds;
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
        uint8 _blockInterval
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

        // effects
        name = _name;
        drawingInterval = _drawingInterval;
        nextDrawingDate = _firstDrawingDate;
        numbersPerTicket = _numbersPerTicket;
        maxDrawableNumber = _maxDrawableNumber;
        ticketPrice = _ticketPrice;
        prizeDistribution = _prizeDistribution;
        blockInterval = _blockInterval;

        // initializations
        drawingIndex = 0;
        drawingCounter = 1;
        seedCounter = 1;

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
    function _mapTicketNumbers(uint16[] numbers, uint ticketId, uint32 drawingId) {
        for (uint8 i = 0; i < numbers.length; i++) {
            draws[drawingId].numbersMap[numbers[i]].push(ticketId);
        }
    }

    // Expose the map of numbers x ticket
    // TODO: change from constant -> view
    function numbersMap(uint32 drawingId, uint16 number) public constant returns (uint[]) {
        return draws[drawingId].numbersMap[number];
    }

    // Is it time to move to next drawing?
    function _nextDrawing() internal {
       // if itsssssss time....!!!!
       if (nextDrawingDate <= now) {
           // if the current drawing has betters (tickets > 0)
           if (draws[drawingCounter].ticketCounter > 0) {
               draws[drawingCounter].nextBlockNumber = block.number + blockInterval;
               _setDrawingStatus(drawingCounter, Status.Drawing); // put it in drawing mode
           } else { // if has not just finish
               _setDrawingStatus(drawingCounter, Status.Finished); // if has not end it
           }
           // if has passed a long time move the lottery ahead skipping till there
           // this gas is on the user but there's nothing we can do about it :D
           for (uint32 i = 0; nextDrawingDate <= now; i++) {
               drawingIndex = (drawingIndex + 1) % drawingInterval.length;
               nextDrawingDate += drawingInterval[drawingIndex];
               drawingCounter++;
               // TODO event to the skips ???
           }
           // start new drawing
           _setDrawingStatus(drawingCounter, Status.Running); // if has not end it
       }
    }

    // Drawn a seed
    function _drawSeed(uint32 drawingId) internal {
        // if itsssssss time... !!!!
        if (block.number >= draws[drawingId].nextBlockNumber) {
            // move to next drawing
            draws[drawingId].nextBlockNumber = block.number + blockInterval;
            // draw a number
            draws[drawingId].seeds.push(block.blockhash(block.number - blockInterval));
            // check if its the last one
            if (draws[drawingId].seeds.length == numbersPerTicket) {
                _setDrawingStatus(drawingId, Status.Drawn);
            }
        }
    }

    // Is it time(block) to draw a new number
    function _isDrawing() internal {
        // theres is something on the line (online!!!!)
        if (drawingCounter > seedCounter) {
            // find next in drawing states
            for (; seedCounter <= drawingCounter; seedCounter++) {
                if (draws[seedCounter].status == Status.Drawing) {
                    _drawSeed(seedCounter);
                    break;
                }
            }
        }
    }

    // Drawn the numbers
    function drawNumber(uint32 drawingId) {
        // process it only if is ready
        if (draws[drawingId].status == Status.Drawn) {
            // and the wizard says: THE PAST SHALL NOT CHANGE
            bytes32 seed = block.blockhash(block.number - blockInterval);
            uint currentIndex = draws[drawingId].winningNumbers.length;
            bytes32 numberSeed = keccak256(seed, draws[drawingId].seeds[currentIndex]);
            uint16 drawnNumber = (uint16(numberSeed) % maxDrawableNumber) + 1;
            bool notDrawnYet = true;
            for (uint i = 0; i < draws[drawingId].winningNumbers.length; i++) {
                if (draws[drawingId].winningNumbers[i] == drawnNumber) {
                    notDrawnYet = false;
                    break;
                }
            }
            if (notDrawnYet) {
                draws[drawingId].winningNumbers.push(drawnNumber);
                NumberWasDrawed(drawingId, drawnNumber);
            }

            if (draws[drawingId].winningNumbers.length == numbersPerTicket) {
                _setDrawingStatus(drawingId, Status.Awarding);
            }
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

        // check if is drawing numbers
        _isDrawing();

        // effects
        draws[drawingCounter].ticketCounter += 1; // increment ticket

        // add the new ticket
        draws[drawingCounter].tickets[draws[drawingCounter].ticketCounter] = Ticket({
            numbers: numbers,
            holder: msg.sender,
            hits: 0
        });

        // add value to the total prize
        draws[drawingCounter].totalPrize += msg.value;
        _mapTicketNumbers(numbers, draws[drawingCounter].ticketCounter, drawingCounter);

        // actions
        NewTicket(drawingCounter, msg.sender, draws[drawingCounter].ticketCounter, numbers);
    }

    // Contract doesnt accept money w/o a ticket
    function () payable {
        revert();
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

            // TODO remove 1% fee - remove ETH foundation fee
            // prize share calculation
            uint noWinnersAmount;
            for (hits = minimalHitsForPrize; hits <= numbersPerTicket; hits++) {
                draws[drawingId].winnersPerHit[hits].prize = (draws[drawingId].totalPrize * prizeDistribution[hits - 1]) / 100;
                if (draws[drawingId].winnersPerHit[hits].tickets.length > 0) {
                    // we got winners
                    draws[drawingId].winnersPerHit[hits].prizeShare = (draws[drawingId].winnersPerHit[hits].prize / draws[drawingId].winnersPerHit[hits].tickets.length);
                } else {
                    // no winners share = prize
                    draws[drawingId].winnersPerHit[hits].prizeShare = draws[drawingId].winnersPerHit[hits].prize;
                    noWinnersAmount += draws[drawingId].winnersPerHit[hits].prize;
                }
                AnnouncePrize(drawingId, hits, draws[drawingId].winnersPerHit[hits].tickets.length, draws[drawingId].winnersPerHit[hits].prizeShare);
            }
            // move all money without winners (diference) to the current drawing
            if (noWinnersAmount > 0) {
                draws[drawingCounter].totalPrize += noWinnersAmount;
                AccumulatedPrizeMoved(drawingId, noWinnersAmount, drawingCounter);
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
}
