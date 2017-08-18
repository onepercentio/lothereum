// eslint *nouppercase
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
 * lotteries, and it also intent to give some
 * of its own profit to charity and a fixed
 * amount to maintainers, developer and ethereum
 * foundation
 * 
 */

contract Lothereum {
    uint[] public drawingInterval; // Time interval between consecutive drawings (ms)
    uint public nextDrawingIndex; // current index of the drawing interval array
    uint public nextDrawing; // timestamp of next drawing date (unix)

    uint public numbersInTicket;
    uint16 public maxDrawableNumber;   

    uint public ticketPrice;

    struct Ticket {
        uint16[] numbers;
        address holder;     
    }
    uint ticketCounter;
    mapping(uint => Ticket) tickets;

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
        require(msg.value >= ticketPrice);
        require(numbers.length == numbersInTicket);

        ticketCounter++;
    }

    // check the order must be crescent and the max number mustnt be lesser or equal then maxDrawable nubmer 
    function areValidNumbers(uint16[] storage numbers) internal {

    }

}