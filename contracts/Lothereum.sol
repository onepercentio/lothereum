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
    uint[] public drawingInterval; // Time interval between consecutive drawings (ms)
    uint public drawingIndex; // current index of the drawing interval array
    uint public nextDrawingDate; // timestamp of next drawing date (unix)
    uint32 public drawingCounter; // how many drawnings so far
    
    uint8[] public prizeDistribution;
    uint16 public maxDrawableNumber; // the highest number starting in 1
    uint8 public minimalHitsForPrize;
    uint8 public numbersPerTicket; // how many numbers must have in the ticket
    uint public ticketPrice; // exactly the transaction value to get a ticket
    mapping(address => uint) public vault; // keep winners money

    uint32[] public drawingQueue; // while drawing

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
    event NumberWasDrawed(uint16 number, uint32 drawingNumber);
    event AnnounceWinner(uint ticketId, uint8 hits, uint32 drawingNumber);
    event AnnouncePrize(uint8 hits, uint numberOfWinners, uint prize, uint32 drawingNumber);
    event AnnounceDrawing(uint32 drawingNumber, Status status);

    // Drawing stuff
    enum Status { Running, Drawing, Finished }
    struct Drawing {
        Status status;
        uint totalPrize;
        mapping(uint8 => WinningBets) winners;
        uint[] winningTickets; // tickets jackpot
        uint16[] winningNumbers; // the numbers drawed
        mapping(uint16 => uint[]) numbersMap; // map numbers per ticket 
        mapping(uint => Ticket) tickets;
        uint ticketCounter;
    }
    mapping(uint32 => Drawing) public draw;

    // @ __TESTS__
    event ConsoleLog(uint log);

    function Lothereum(
        string _name,
        uint[] _drawingInterval,
        uint _firstDrawingDate,
        uint8 _numbersPerTicket,
        uint16 _maxDrawableNumber,
        uint _ticketPrice,
        uint8[] _prizeDistribution
    ) {
        // Validations
        require(_ticketPrice > 0);
        require(_maxDrawableNumber > 0);
        require(_numbersPerTicket > 0);
        require(_numbersPerTicket < _maxDrawableNumber);
        require(_prizeDistribution.length == _numbersPerTicket);
        require(_drawingInterval.length > 0 && _drawingInterval.length < 100);
        require(_firstDrawingDate > now);

        uint8 prizeDistributionCheck;
        for (uint8 i; i < _prizeDistribution.length ; i++){
            prizeDistributionCheck += _prizeDistribution[i];
            if (minimalHitsForPrize == 0 && _prizeDistribution[i] != 0) minimalHitsForPrize = i + 1;
        }
        require(prizeDistributionCheck == 100);

        for (uint8 j; j < _drawingInterval.length ; j++){
            require(_drawingInterval[j] >= 60);            
        }

        // Effects - init
        name = _name;
        prizeDistribution = _prizeDistribution;
        drawingInterval = _drawingInterval;
        nextDrawingDate = _firstDrawingDate;        
        numbersPerTicket = _numbersPerTicket;
        maxDrawableNumber = _maxDrawableNumber;
        ticketPrice = _ticketPrice;
        drawingIndex = 0;
        drawingCounter = 1;
        // it's by default but we need to announce it
        _setDrawingStatus(Status.Running); // if has not end it    
    }

    // @ __TESTS__
    function getNumbersMap(uint32 drawId, uint16 number) constant public returns (uint[]) {
        return draw[drawId].numbersMap[number];
    }
    // @ __TESTS__
    function getStatus(uint32 drawId) constant public returns (Status) {
        return draw[drawId].status;
    }
    // @ __TESTS__
    function getNow() constant public returns (uint) {
        return now;
    }

    // @ __INTERNAL__
    function _setDrawingStatus(Status _status) internal {
        draw[drawingCounter].status = _status;
        AnnounceDrawing(drawingCounter, _status);
    }

    // @ __INTERNAL__
    function _nextDrawing(uint _now) public {
        // if itsssssss time....!!!!
        if (nextDrawingDate <= _now) {
            // if the current drawing has betters (tickets > 0)
            if (draw[drawingCounter].ticketCounter > 0) {
                drawingQueue.push(drawingCounter); // put on the line (online!)
                _setDrawingStatus(Status.Drawing); // put it in drawing mode
            } else {
                _setDrawingStatus(Status.Finished); // if has not end it    
            }            
            // if has passed a long time move the lottery ahead skipping till there
            // this gas is on the user but there's nothing we can do about it :D
            for (uint32 i = 0; nextDrawingDate <= _now; i++) {
                drawingIndex = (drawingIndex + 1) % drawingInterval.length;
                nextDrawingDate += drawingInterval[drawingIndex];                
                drawingCounter++;
            }
            // it's by default but we need to announce it
            _setDrawingStatus(Status.Running); // if has not end it    
        }
    }

    // Check the order must be crescent and the max number mustnt be lesser then maxDrawable nubmer     
    // @ __INTERNAL__
    function _areValidNumbers(uint16[] numbers, uint16 maxNumber) constant public returns (bool) {
        if (numbers[numbers.length - 1] > maxNumber) return false;
        for (uint8 i; i < numbers.length - 2; i++) {
            if (numbers[i] >= numbers[i + 1]) return false;
        }
        return true;
    }

    // Ticket purchase
    function buyTicket(uint16[] numbers) payable {
        // validations
        require(msg.value == ticketPrice);
        require(numbers.length == numbersPerTicket);
        require(_areValidNumbers(numbers, maxDrawableNumber));

        // if its a new drawing 
        _nextDrawing(now);

        // effects
        draw[drawingCounter].ticketCounter += 1;
        uint ticketCounter = draw[drawingCounter].ticketCounter;
        
        draw[drawingCounter].tickets[ticketCounter] = Ticket({
            numbers: numbers,
            holder: msg.sender,
            hits: 0
        });

        draw[drawingCounter].totalPrize += msg.value;
        draw[drawingCounter].tickets[ticketCounter] = Ticket({
            numbers: numbers,
            holder: msg.sender,
            hits: 0
        });        
        _mapTicketNumbers(numbers, ticketCounter, drawingCounter);

        // actions
        NewTicket(drawingCounter, msg.sender, ticketCounter, numbers);
    }

    // Save tickets per number 
    // @ __INTERNAL__
    function _mapTicketNumbers(uint16[] numbers, uint ticketId, uint32 drawingId) {
        for (uint8 i; i < numbers.length; i++) {
            draw[drawingId].numbersMap[numbers[i]].push(ticketId);
        }        
    }

    // @ __INTERNAL__
    function _numberAlreadyDrawed(uint16 newNumber, uint16[] drawed) constant public returns (bool) {        
        for (uint16 i; i < drawed.length; i++) {
            if (drawed[i] == newNumber) return true;
        }
        return false;
    }

    // random (will be changed) don't worry
    // @ __INTERNAL__
    function _generateRandomNumber(uint seed, uint16 mod) constant public returns (uint16) {
        return (uint16(sha3(block.blockhash(block.number - 1), seed)) % mod) + 1;
    }

    // let's put the drawing into drawing mode
    // @ __INTERNAL__
    // function _processDraw(uint32 drawingId) public {
        // if (now < nextDrawingDate) return;
        // uint16 number = _generateRandomNumber(now, maxDrawableNumber);
        // if (_validateDrawedNumber(number, winningNumbers, numbersPerTicket)) {
        //     winningNumbers.push(number);
        //     NumberWasDrawed(number, drawingCounter);
        // }

        // did i finish? process winners
    // }

    // jackpot ?
    // @ __INTERNAL__
    // function _checkWinners(uint16[] _winningNumbers) {
        // first we flag all winning tickets
        // for (uint16 i; i < _winningNumbers.length; i++) {
        //     // this is all ticket ids that bet in number "winningNumbers[i]"
        //     // numbersMap[winningNumbers[i]];
        //     for (uint j = 0; j < numbersMap[_winningNumbers[i]].length; j++) {
        //         tickets[numbersMap[_winningNumbers[i]][j]].hits++;
        //         // if hit enough numbers 0 = least numbers to prize
        //         if (tickets[numbersMap[_winningNumbers[i]][j]].hits == minimalHitsForPrize) {
        //             winningTickets.push(numbersMap[_winningNumbers[i]][j]);
        //         }
        //     }
        // }

        // then, we distribute the available prizes
        // for (uint8 hits = minimalHitsForPrize; hits <= numbersPerTicket; hits++) {
        //     uint totalPrizeForNHits = (totalPrize * prizeDistribution[hits-1]) / 100;
        //     for (uint w = 0; w < winningTickets.length; w++){
        //         if (tickets[winningTickets[w]].hits == hits){
        //             winners[hits].tickets.push(winningTickets[w]);
        //             AnnounceWinner(winningTickets[w], hits, drawingCounter);
        //         }
        //     }
        //     if (winners[hits].tickets.length > 0){
        //         winners[hits].prizeShare = totalPrizeForNHits / winners[hits].tickets.length;
        //         AnnouncePrize(hits, winners[hits].tickets.length, winners[hits].prizeShare, drawingCounter);
        //         for (uint p = 0; p < winners[hits].tickets.length; p++) {
        //             vault[tickets[winners[hits].tickets[p]].holder] += winners[hits].prizeShare;
        //         }
        //     }
        // }
    // }
}