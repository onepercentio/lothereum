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
    
    uint8[] public prizeDistribution;
    uint16 public maxDrawableNumber; // the highest number starting in 1
    uint8 public minimalHitsForPrize;
    uint8 public numbersPerTicket; // how many numbers must have in the ticket
    uint public ticketPrice; // exactly the transaction value to get a ticket
    mapping(address => uint) public vault; // keep winners money

    uint32 drawingInProcess;

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

    // @ __TESTS__
    event ConsoleLog(uint log);

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
        // Validations
        require(_ticketPrice > 0);
        require(_maxDrawableNumber > 0);
        require(_numbersPerTicket > 0);
        require(_numbersPerTicket < _maxDrawableNumber);
        require(_prizeDistribution.length == _numbersPerTicket);
        require(_drawingInterval.length > 0 && _drawingInterval.length < 100);
        require(_firstDrawingDate > now);
        require(_blockInterval > 7);

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
        blockInterval = _blockInterval;
        prizeDistribution = _prizeDistribution;
        drawingInterval = _drawingInterval;
        nextDrawingDate = _firstDrawingDate;        
        numbersPerTicket = _numbersPerTicket;
        maxDrawableNumber = _maxDrawableNumber;
        ticketPrice = _ticketPrice;
        drawingIndex = 0;
        drawingCounter = 1;
        // it's by default but we need to announce it
        _setDrawingStatus(drawingCounter, Status.Running);  
    }

    // @ __TESTS__
    function getNumbersMap(uint32 drawId, uint16 number) constant public returns (uint[]) {
        return draws[drawId].numbersMap[number];
    }
    // @ __TESTS__
    function getStatus(uint32 drawId) constant public returns (Status) {
        return draws[drawId].status;
    }
    // @ __TESTS__
    function getNow() constant public returns (uint) {
        return now;
    }

    // @ __INTERNAL__
    function _setDrawingStatus(uint32 drawId, Status _status) internal {
        draws[drawId].status = _status;
        AnnounceDrawing(drawId, _status);
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

    // random (it will be changed) don't worry
    // @ __INTERNAL__
    function _generateRandomNumber(uint seed, uint16 mod) constant public returns (uint16) {
        return (uint16(sha3(block.blockhash(block.number - 1), seed)) % mod) + 1;
    }

    // @ __INTERNAL__
    function _numberAlreadyDrawed(uint16 newNumber, uint16[] numbersDrawed) constant public returns (bool) {        
        for (uint16 i; i < numbersDrawed.length; i++) {
            if  (numbersDrawed[i] == newNumber) return true;
        }
        return false;
    }

    // Save tickets per number 
    // @ __INTERNAL__
    function _mapTicketNumbers(uint16[] numbers, uint ticketId, uint32 drawingId) {
        for (uint8 i; i < numbers.length; i++) {
            draws[drawingId].numbersMap[numbers[i]].push(ticketId);
        }        
    }

    // @ __INTERNAL__
    function _nextDrawing(uint _now) public {
        // if itsssssss time....!!!!
        if (nextDrawingDate <= _now) {
            // if the current drawing has betters (tickets > 0)
            if (draws[drawingCounter].ticketCounter > 0) {
                drawingInProcess = drawingCounter; // put on the line (online!)
                draws[drawingCounter].nextBlockNumber = block.number + blockInterval;
                _setDrawingStatus(drawingCounter, Status.Drawing); // put it in drawing mode
            } else {
                _setDrawingStatus(drawingCounter, Status.Finished); // if has not end it    
            }            
            // if has passed a long time move the lottery ahead skipping till there
            // this gas is on the user but there's nothing we can do about it :D
            for (uint32 i = 0; nextDrawingDate <= _now; i++) {
                drawingIndex = (drawingIndex + 1) % drawingInterval.length;
                nextDrawingDate += drawingInterval[drawingIndex];                
                drawingCounter++;
                // TODO event to the skips ???
            }
            // it's by default but we need to announce it
            _setDrawingStatus(drawingCounter, Status.Running); // if has not end it    
        }
    }

    // __INTERNAL__ ??    
    function draw(uint blockNumber) public {
        uint32 _drawingCounter = drawingQueue[drawingQueueIndex];
        if (blockNumber >= draws[_drawingCounter].nextBlockNumber) {
            // will be a new seed - poke poke
            uint16 number = _generateRandomNumber(now, maxDrawableNumber);
            if (!_numberAlreadyDrawed(number, draws[_drawingCounter].winningNumbers)) {
                // push number to result
                draws[_drawingCounter].winningNumbers.push(number);
                // set next drawn after block x
                draws[_drawingCounter].nextBlockNumber += blockInterval;
                // announce it to the world
                NumberWasDrawed(_drawingCounter, number);
                // is it the last number?
                if (draws[_drawingCounter].winningNumbers.length == numbersPerTicket) {
                    // move pointer
                    drawingQueueIndex++;
                    _setDrawingStatus(_drawingCounter, Status.Awarding);
                }
            }
        }
    }

    // Ticket purchase
    function buyTicket(uint16[] numbers) payable {
        // validations
        require(msg.value == ticketPrice);
        require(numbers.length == numbersPerTicket);
        require(_areValidNumbers(numbers, maxDrawableNumber));

        // if its a new drawing process for this ticket
        _nextDrawing(now);

        // if its time to draw a number
        if (drawingQueue.length > drawingQueueIndex) {
            draw(block.number);
        }

        // effects
        draws[drawingCounter].ticketCounter += 1;
        uint ticketCounter = draws[drawingCounter].ticketCounter;
        
        draws[drawingCounter].tickets[ticketCounter] = Ticket({
            numbers: numbers,
            holder: msg.sender,
            hits: 0
        });

        draws[drawingCounter].totalPrize += msg.value;
        draws[drawingCounter].tickets[ticketCounter] = Ticket({
            numbers: numbers,
            holder: msg.sender,
            hits: 0
        });        
        _mapTicketNumbers(numbers, ticketCounter, drawingCounter);

        // actions
        NewTicket(drawingCounter, msg.sender, ticketCounter, numbers);
    }

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