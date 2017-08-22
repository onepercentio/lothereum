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
    uint public nextDrawingDate; // timestamp of next drawing date (unix)
    uint32 public drawingCounter; // how many drawnings so far
    
    uint8[] public prizeDistribution;
    uint16 public maxDrawableNumber; // the highest number starting in 1
    uint8 public minimalHitsForPrize;
    uint8 public numbersInTicket; // how many numbers must have in the ticket
    uint public ticketPrice; // exactly the transaction value to get a ticket
    mapping(address => uint) public vault;

    // Ticket stuff
    struct Ticket {
        uint16[] numbers;
        address holder;
        uint8 hits;
    }
    uint public ticketCounter; // how many tickets so far
    mapping(uint => Ticket) public tickets;

    // events
    event NewTicket(address holder, uint ticketId, uint16[] numbers, uint32 drawingNumber);
    event NumberWasDrawed(uint16 number, uint32 drawingNumber);
    event AnnounceWinner(uint ticketId, uint8 hits, uint32 drawingNumber);
    event AnnouncePrize(uint8 hits, uint numberOfWinners, uint prize, uint32 drawingNumber);

    // THIS ----- will be inside the "DRAWING" struct
    mapping(uint16 => uint[]) public numbersMap; // map numbers per ticket
    uint16[] winningNumbers; // the numbers drawed
    uint[] public winningTickets; // tickets jackpot
    struct WinningBets {
        uint prizeShare;
        uint[] tickets;
    }
    mapping(uint8 => WinningBets) public winners;
    uint public totalPrize;
    // last bought ticket
    // drawing status
    //   <----------- THIS

    // DELETE THIS
    event ConsoleLog(uint log);

    function Lothereum(
        uint[] _drawingInterval,
        uint firstDrawingDate,
        uint8 _numbersInTicket,
        uint16 _maxDrawableNumber,
        uint _ticketPrice,
        uint8[] _prizeDistribution
    ) {
        require(_ticketPrice > 0);
        require(_maxDrawableNumber > 0);
        require(_numbersInTicket > 0);
        require(_numbersInTicket < _maxDrawableNumber);

        require(_prizeDistribution.length == _numbersInTicket);
        uint8 prizeDistributionCheck;
        for(uint8 i; i < _prizeDistribution.length ; i++){
            prizeDistributionCheck += _prizeDistribution[i];
            if(minimalHitsForPrize == 0 && _prizeDistribution[i] != 0) minimalHitsForPrize = i + 1;
        }
        require(prizeDistributionCheck == 100);

        prizeDistribution = _prizeDistribution;
        drawingInterval = _drawingInterval;
        nextDrawingDate = firstDrawingDate;
        nextDrawingIndex = 0;
        numbersInTicket = _numbersInTicket;
        maxDrawableNumber = _maxDrawableNumber;
        ticketPrice = _ticketPrice;
    }

    function setNextDrawing() {
        nextDrawingDate = nextDrawingDate + drawingInterval[nextDrawingIndex];
        nextDrawingIndex = (nextDrawingIndex + 1) % drawingInterval.length;
    }

    function buyTicket(uint16[] numbers) payable {
        //get rekt
        processDraw();

        // validations
        require(msg.value == ticketPrice);
        require(numbers.length == numbersInTicket);
        require(areValidNumbers(numbers, maxDrawableNumber));

        // effects
        totalPrize += msg.value;
        ticketCounter += 1;
        uint ticketId = ticketCounter;
        tickets[ticketId] = Ticket({
            numbers: numbers,
            holder: msg.sender,
            hits: 0
        });
        _mapTicketNumbers(numbers, ticketId);

        // actions
        NewTicket(msg.sender, ticketId, numbers, drawingCounter);
    }

    // check the order must be crescent and the max number mustnt be lesser or equal then maxDrawable nubmer 
    function areValidNumbers(uint16[] numbers, uint16 maxNumber) constant returns (bool) {
        if (numbers[numbers.length - 1] > maxNumber) return false;
        for (uint8 i; i < numbers.length - 2; i++) {
            if (numbers[i] >= numbers[i+1]) return false;
        }
        return true;
    }

    function _validateDrawedNumber(uint16 number, uint16[] drawed, uint maxLength) returns (bool) {
        if(drawed.length < maxLength){
            for (uint16 i; i < drawed.length; i++) {
                if (drawed[i] == number) return false;
            }
            return true;
        }
    }

    function _mapTicketNumbers(uint16[] numbers, uint ticketId) {
        for (uint8 i; i < numbers.length; i++) {
            numbersMap[numbers[i]].push(ticketId);
        }
        
    }

    function _generateRandomNumber(uint seed, uint16 mod) returns (uint16){
        return (uint16(sha3(block.blockhash(block.number-1), seed)) % mod) + 1;
    }

    function processDraw() {
        if(now < nextDrawingDate) return;
        uint16 number = _generateRandomNumber(now, maxDrawableNumber);
        if(_validateDrawedNumber(number, winningNumbers, numbersInTicket)){
            winningNumbers.push(number);
            NumberWasDrawed(number, drawingCounter);
        }

        // did i finish? process winners
    }

    function _checkWinners(uint16[] _winningNumbers) {
        // first we flag all winning tickets
        for(uint16 i; i < _winningNumbers.length; i++) {
            // this is all ticket ids that bet in number "winningNumbers[i]"
            // numbersMap[winningNumbers[i]];
            for(uint j = 0; j < numbersMap[_winningNumbers[i]].length; j++) {
                tickets[numbersMap[_winningNumbers[i]][j]].hits++;
                // if hit enough numbers 0 = least numbers to prize
                if (tickets[numbersMap[_winningNumbers[i]][j]].hits == minimalHitsForPrize) {
                    winningTickets.push(numbersMap[_winningNumbers[i]][j]);
                }
            }
        }

        // then, we distribute the available prizes
        for(uint8 hits = minimalHitsForPrize; hits <= numbersInTicket; hits++){
            uint totalPrizeForNHits = totalPrize *  prizeDistribution[hits-1] / 100;
            for(uint w = 0; w < winningTickets.length; w++){
                if(tickets[winningTickets[w]].hits == hits){
                    winners[hits].tickets.push(winningTickets[w]);
                    AnnounceWinner(winningTickets[w], hits, drawingCounter);
                }
            }
            if(winners[hits].tickets.length > 0){
                winners[hits].prizeShare = totalPrizeForNHits / winners[hits].tickets.length;
                AnnouncePrize(hits, winners[hits].tickets.length, winners[hits].prizeShare, drawingCounter);
                for(uint p = 0; p < winners[hits].tickets.length; p++){
                    vault[tickets[winners[hits].tickets[p]].holder] += winners[hits].prizeShare;
                }
            }
        }
    }
}