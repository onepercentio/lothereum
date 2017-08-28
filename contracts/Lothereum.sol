pragma solidity ^0.4.13;

// interval in anything
// start in - bootstrap
// next - move to start i

// tickets gonna hold holder and numbers
// numbers with tickets that bet on it
// check numbers[tickets] and increment

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
    // Constant
    string constant VERSION = '1.0.1';

    // Meta attributes
    string name;
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

    uint32 drawingInProcess; // pointer

    // Ticket stuff
    struct Ticket {
        uint16[] numbers;
        address holder;
        uint8 hits;
    }

    // Winning stuff
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

    // TESTS
    event ConsoleLog(
        string _name,
        uint[] _drawingInterval,
        uint _firstDrawingDate,
        uint8 _numbersPerTicket,
        uint16 _maxDrawableNumber,
        uint _ticketPrice,
        uint8[] _prizeDistribution,
        uint32 _blockInterval);

    // Drawing stuff
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

        ConsoleLog(
          name,
          drawingInterval,
          nextDrawingDate,
          numbersPerTicket,
          maxDrawableNumber,
          ticketPrice,
          prizeDistribution,
          blockInterval);

          require(false);

        /*_setDrawingStatus(drawingCounter, Status.Running);*/

        // Validations
        /*require(_ticketPrice > 0);
        require(_maxDrawableNumber > 0);
        require(_numbersPerTicket > 0);
        require(_numbersPerTicket < _maxDrawableNumber);
        require(_prizeDistribution.length == _numbersPerTicket);
        require(_drawingInterval.length > 0 && _drawingInterval.length < 100);
        require(_firstDrawingDate > now);*/
        /*require(_blockInterval > 7);*/

    }
}
               // drawingInProcess = drawingCounter; // put on the line (online!)