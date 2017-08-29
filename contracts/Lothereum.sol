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
    uint32 public blockInterval; // Timelapse between one number drawning
    uint[] public drawingInterval; // Time interval between consecutive drawings (ms)
    uint public drawingIndex; // current index of the drawing interval array
    uint public nextDrawingDate; // timestamp of next drawing date (unix)
    uint32 public drawingCounter; // how many drawnings so far
    uint8[] public prizeDistribution; // rules of distribution
    uint16 public maxDrawableNumber; // the highest number starting in 1
    uint8 public minimalHitsForPrize;
    uint8 public numbersPerTicket; // how many numbers must have in the ticket
    uint public ticketPrice; // exactly the transaction value to get a ticket*/
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

    // Events
    event NewTicket(uint32 drawingNumber, address holder, uint ticketId, uint16[] numbers);
    event NumberWasDrawed(uint32 drawingNumber, uint16 number);
    event AnnounceWinner(uint ticketId, uint8 hits, uint32 drawingNumber);
    event AnnouncePrize(uint8 hits, uint numberOfWinners, uint prize, uint32 drawingNumber);
    event AnnounceDrawing(uint32 drawingNumber, Status status);

    // Drawing
    enum Status { Running, Drawing, Awarding, Finished }
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
        uint32 _blockInterval
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
        require(_blockInterval > 7);
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
        drawingIndex = 0;
        drawingCounter = 1;

        _setDrawingStatus(drawingCounter, Status.Running);
    }

    // Announce the new status
    function _setDrawingStatus(uint32 drawId, Status _status) internal {
        draws[drawId].status = _status;
        AnnounceDrawing(drawId, _status);
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
           } else {
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
           // it's by default but we need to announce it
           _setDrawingStatus(drawingCounter, Status.Running); // if has not end it
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
        draws[drawingCounter].totalPrize += msg.value;
        _mapTicketNumbers(numbers, draws[drawingCounter].ticketCounter, drawingCounter);

        // actions
        NewTicket(drawingCounter, msg.sender, draws[drawingCounter].ticketCounter, numbers);
    }

    // Contract doesnt accept money w/o a ticket
    function () payable {
        revert();
    }
}
