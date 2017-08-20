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
 * lotteries, it also intents to give some
 * of its own profit to charity and a fixed
 * amount to maintainers, developer and ethereum
 * foundation, every one is welcome to support 1% community
 * soon we gonna have all our rules on Solidity, till there mail us!
 * 
 */

contract Lothereum {
    uint[] public drawingInterval; // Time interval between consecutive drawings (ms)
    uint public nextDrawingIndex; // current index of the drawing interval array
    uint public nextDrawing; // timestamp of next drawing date (unix)
    uint32 public drawingCounter; // how many drawnings so far

    uint public numbersInTicket; // how many numbers must have in the ticket
    uint16 public maxDrawableNumber; // the highest number starting in 1

    uint public ticketPrice; // exactly the transaction value to get a ticket

    struct Ticket {
        uint16[] numbers;
        address holder;     
    }
    uint public ticketCounter; // how many tickets so far
    mapping(uint => Ticket) public tickets;
    event NewTicket(address holder, uint ticketId, uint16[] numbers);

    function Lothereum(
        uint[] _drawingInterval,
        uint firstDrawingDate,
        uint8 _numbersInTicket,
        uint16 _maxDrawableNumber,
        uint _ticketPrice
    ) {
        drawingInterval = _drawingInterval;
        nextDrawing = firstDrawingDate;
        nextDrawingIndex = 0;
        numbersInTicket = _numbersInTicket;
        maxDrawableNumber = _maxDrawableNumber;
        ticketPrice = _ticketPrice;
    }

    function setNextDrawing() {
        nextDrawing = nextDrawing + drawingInterval[nextDrawingIndex];
        nextDrawingIndex = (nextDrawingIndex + 1) % drawingInterval.length;
    }

    function buyTicket(uint16[] numbers) payable {
        // validations
        require(msg.value == ticketPrice);
        require(numbers.length == numbersInTicket);
        require(areValidNumbers(numbers, maxDrawableNumber));

        // effects
        ticketCounter += 1;
        uint ticketId = ticketCounter;
        tickets[ticketId] = Ticket({
            numbers: numbers,
            holder: msg.sender
        });

        // actions
        NewTicket(msg.sender, ticketId, numbers);
    }

    // check the order must be crescent and the max number mustnt be lesser or equal then maxDrawable nubmer 
    function areValidNumbers(uint16[] numbers, uint16 maxNumber) returns (bool) {
        if (numbers[numbers.length - 1] > maxNumber) return false;
        for (uint8 i; i < numbers.length - 2; i++) {
            if (numbers[i] >= numbers[i+1]) return false;
        }
        return true;
    }

}