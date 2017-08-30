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
        uint prizeShare;
        uint[] tickets;
    }

    // Drawing seed generator
    uint32 seedCounter;

    // Events
    event NewTicket(uint32 drawing, address holder, uint ticketId, uint16[] numbers);
    event NumberWasDrawed(uint32 drawing, uint16 number);
    event AnnounceDrawing(uint32 drawing, Status status);

    event AnnounceWinner(uint ticketId, uint8 hits, uint32 drawing);
    event AnnouncePrize(uint8 hits, uint numberOfWinners, uint prize, uint32 drawing);

    // Drawing
    enum Status { Skipped, Running, Drawing, Drawn, Awarding, Finished }
    struct Drawing {
        Status status;
        uint totalPrize;
        mapping(uint8 => WinningBets) winners;
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
        require(_drawingInterval.length > 0 && _drawingInterval.length < 100);
        for (uint8 j; j < _drawingInterval.length ; j++) {
            require(_drawingInterval[j] >= 60);
        }
        require(_firstDrawingDate > now);
        require(_numbersPerTicket > 0 && _numbersPerTicket < 51);
        require(_maxDrawableNumber > 0 && _maxDrawableNumber < 65535);
        require(_ticketPrice > 0);
        require(_prizeDistribution.length == _numbersPerTicket);
        uint8 prizeDistributionCheck;
        for (uint8 i; i < _prizeDistribution.length ; i++) {
            prizeDistributionCheck += _prizeDistribution[i];
            if (minimalHitsForPrize == 0 && _prizeDistribution[i] != 0) minimalHitsForPrize = i + 1;
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
        if (numbers[numbers.length - 1] > maxNumber) return false;
        for (uint8 i; i < numbers.length - 1; i++) {
            if (numbers[i] >= numbers[i + 1]) return false;
        }
        return true;
    }

    // To make the drawing easier
    function _mapTicketNumbers(uint16[] numbers, uint ticketId, uint32 drawingId) {
        for (uint8 i; i < numbers.length; i++) {
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
        if (block.number => draws[drawingId].nextBlockNumber) {
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

    // Drawn the whole numbers ONLY US NO GAS TO THE USER
    function _drawResult(uint32 drawingId) {
        // process it only if is ready
        if (draws[drawingId].status == Status.Drawn) {
            bytes32 seed = block.blockhash(block.number - blockInterval);
            // JOHN - ALGORITHM OF HEAVEN
            // check winners
            // fund vault
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

    // results
    function _checkWinners(uint32 drawingId) {
        // first we flag all winning tickets
        uint16 number;
        uint ticketId;
        for (uint8 i; i < draws[drawingId].winningNumbers.length; i++) {
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
        // then, we distribute the available prizes
        for (uint8 hits = minimalHitsForPrize; hits <= numbersPerTicket; hits++) {
            uint totalPrizeForNHits = (totalPrize * prizeDistribution[hits-1]) / 100;
            for (uint w = 0; w < winningTickets.length; w++) {
                if (tickets[winningTickets[w]].hits == hits) {
                    winners[hits].tickets.push(winningTickets[w]);
                    AnnounceWinner(winningTickets[w], hits, drawingCounter);
                 }
             }
             if (winners[hits].tickets.length > 0) {
                winners[hits].prizeShare = totalPrizeForNHits / winners[hits].tickets.length;
                AnnouncePrize(hits, winners[hits].tickets.length, winners[hits].prizeShare, drawingCounter);
                for (uint p = 0; p < winners[hits].tickets.length; p++) {
                    vault[tickets[winners[hits].tickets[p]].holder] += winners[hits].prizeShare;
                }
            }
        }
    }
}
