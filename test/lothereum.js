var Lothereum = artifacts.require("./Lothereum.sol");
const firstDate = Math.round(new Date() / 1000) + 6000
const newInstance = ({interval = [60], first = firstDate, n = 6, max = 60, price = 3500000000000, distribution = [0, 0, 0, 5, 15, 80]} = {}) =>
    Lothereum.new(interval, first, n, max, price, distribution)

contract('Lothereum', (accounts) => {
    // Constructor
    describe('Constructor', () => {
        it("should not allow empty drawing interval or higher then 100 intervals", async function() {
            let throwed = false
            try {
                await newInstance({ interval: []})
            } catch(e) { 
                throwed = true
            }  
            assert(throwed, "it didn't throw an exception")
        })
        it("should not allow drawing interval lesser then 60 1m", async function() {
            let throwed = false
            try {
                await newInstance({ interval: [50]})
            } catch(e) { 
                throwed = true
            }  
            assert(throwed, "it didn't throw an exception")
        })
        it("should not allow first drawing date before now", async function() {
            let throwed = false
            try {
                let instance = await newInstance({ first: 1 })
            } catch (e) {
                throwed = true
            }
            assert(throwed, "it didn't throw an exception")
        })
        it("should not allow for a 0 price lottery ticket", async function() {
            let throwed = false
            try {
                let instance = await newInstance({ price: 0 })
            } catch (e) {
                throwed = true
            }
            assert(throwed, "it didn't throw an exception")
        })
        it("should not allow max drawable number to be 0", async function() {
            let throwed = false
            try {
                let instance = await newInstance({ max: 0 })
            } catch (e) {
                throwed = true
            }
            assert(throwed, "it didn't throw an exception")
        })
        it("should not allow numbers in ticket to be 0", async function() {
            let throwed = false
            try {
                let instance = await newInstance({ n: 0 })
            } catch (e) {
                throwed = true
            }
            assert(throwed, "it didn't throw an exception")
        })
        it("should not allow numbers in ticket < maxDrawableNumber ", async function() {
            let throwed = false
            try {
                let instance = await newInstance({ n: 10, max: 5 })
            } catch (e) {
                throwed = true
            }
            assert(throwed, "it didn't throw an exception")
        })
        it("should require the prizeDistribution to have the same length as n of tickets", async function() {
            let throwed = false
            try {
                let instance = await newInstance({ distribution: [0] })
            } catch (e) {
                throwed = true
            }
            assert(throwed, "it didn't throw an exception")
        })
        it("should require the prizeDistribution to sum 100", async function() {
            let throwed = false
            try {
                let instance = await newInstance({ distribution: [0,0,0,5,15,85] })
            } catch (e) {
                throwed = true
            }
            assert(throwed, "it didn't throw an exception")
        })
        it("should create a lottery with my started drawing definitions", async function() {
            let instance = await newInstance({ first: firstDate + 6000})
            assert.equal(Number(await instance.nextDrawingDate()), firstDate + 6000)
        })
        it("should correctly set minimalHitsForPrize", async function() {
            let instance = await newInstance()
            assert.equal(await instance.minimalHitsForPrize.call(), 4)
        })    
        it("should put the current drawing status to running", async function() {
            let instance = await newInstance()    
            assert.equal(Number(await instance.getStatus.call(1)), 0)
        })
    }) 
    // Next Drawing
    describe('Drawing interval', () => {
        // next Drawing
        it("should correctly set next drawing", async function() {
            let instance = await newInstance({ interval: [1000]})
            await instance.setNextDrawing()            
            assert.equal(Number(await instance.nextDrawingDate()), firstDate + 1000)
            assert.equal(Number(await instance.nextDrawingIndex()), 0)
            assert.equal(Number(await instance.drawingCounter()), 2)
        })
        it("should increment next drawing index and counter", async function() {
            let instance = await newInstance({ interval: [ 200, 400 ]})
            await instance.setNextDrawing()
            assert.equal(Number(await instance.nextDrawingDate()), firstDate + 200)
            assert.equal(Number(await instance.nextDrawingIndex()), 1)
            assert.equal(Number(await instance.drawingCounter()), 2)

            await instance.setNextDrawing()
            assert.equal(Number(await instance.nextDrawingDate()), firstDate + 400 + 200)
            assert.equal(Number(await instance.nextDrawingIndex()), 0)
            assert.equal(Number(await instance.drawingCounter()), 3)
        })
    })    
    // Buying ticket
    describe('Ticket issue', () => {
        describe('validating ticket info', function() {
            it("should check if the array is ordered and the maxnumber is respected", async function() {
                let instance = await newInstance()
                assert.equal(true, await instance._areValidNumbers.call([1,2,3,4], 4))
            })
            it("should invalidate for number > maxnumber", async function() {
                let instance = await newInstance()
                assert.equal(false, await instance._areValidNumbers.call([2], 1))
            })
            it("should invalidate for unordered array", async function() {
                let instance = await newInstance()
                assert.equal(false, await instance._areValidNumbers.call([3,2,1], 60))
            })
            it("should invalidate with two equal values", async function() {
                let instance = await newInstance()
                assert.equal(false, await instance._areValidNumbers.call([3,3,4], 60))
            })
            it("should invalidate a crazy array", async function() {
                let instance = await newInstance()
                assert.equal(false, await instance._areValidNumbers.call([1,3,5,5,9,31,20], 25))
            })
            it('should require sent amount to equal ticketprice', async function() {
                let instance = await newInstance({ price: 100 })
                let throwed = false
                try {
                    await instance.buyTicket.call([10, 20, 30, 40, 50, 60], { from: accounts[0], value: 150 })
                } catch (e) {
                    throwed = true
                }
                assert(throwed, "it didn't throw an exception")
            })
            it('should require numbers length to be correct', async function() {
                let instance = await newInstance({ price: 100 })
                let throwed = false
                try {
                    await instance.buyTicket.call([10, 20, 30, 40, 50], { from: accounts[0], value: 100 })
                } catch (e) {
                    throwed = true
                }
                assert(throwed, "it didn't throw an exception")
            })
        })
        describe('dispatching event', function() {
            it('should tell everyone I bought it', async function() {
                let instance = await newInstance({ price: 100 })
                // if this crashes its because we are lazy and didnt use BigNumbers
                let ticketCounter = Number(await instance.ticketCounter.call())
                let ticketTransaction = await instance.buyTicket([10, 20, 30, 40, 50, 60], { from: accounts[0], value: 100 })
                let { args: myTicket } = ticketTransaction.logs.find( l => l.event == 'NewTicket')
                let newTicketCounter = Number(await instance.ticketCounter.call())

                assert.notEqual(ticketCounter, newTicketCounter)
                assert.equal(newTicketCounter, myTicket.ticketId) 
            })
        })
        describe('effects', function() {
            it('should map all numbers in the ticket', async function() {
                let instance = await newInstance({ price: 120 })
                await instance.buyTicket([10, 20, 30, 40, 50, 60], { from: accounts[0], value: 120 })
                await instance.buyTicket([10, 20, 30, 40, 50, 60], { from: accounts[0], value: 120 })
                await instance.buyTicket([10, 21, 30, 40, 50, 60], { from: accounts[0], value: 120 })
                let r = 0;
                r = await instance.getNumbersMap.call(1, 10);
                assert.equal(3, r.length);
                r = await instance.getNumbersMap.call(1, 30);
                assert.equal(3, r.length);
                r = await instance.getNumbersMap.call(1, 40);
                assert.equal(3, r.length);
                r = await instance.getNumbersMap.call(1, 50);
                assert.equal(3, r.length);
                r = await instance.getNumbersMap.call(1, 60);
                assert.equal(3, r.length);
                r = await instance.getNumbersMap.call(1, 20);
                assert.equal(2, r.length);
                r = await instance.getNumbersMap.call(1, 21);
                assert.equal(1, r.length);
            })
        })
    })
    describe('Drawing the winning numbers', function() {
            it("should allow a new number", async function() {
                let instance = await newInstance()
                assert.equal(false, await instance._numberAlreadyDrawed.call(1, [2, 3, 4, 5, 8]))
            })  
            it("should not allow repeated numbers", async function() {
                let instance = await newInstance({})
                assert.equal(true, await instance._numberAlreadyDrawed.call(1, [2, 3, 4, 5, 1]))            
            })                          
//             it("should not exceed the max length", async function() {
//                 let instance = await newInstance({})
//                 assert.equal(false, await instance._validateDrawedNumber.call(1, [2, 3, 4, 5, 8, 9], 6))                
//             })
//             it("should sort some random numbers (DANGER)", async function() {
//                 let instance = await newInstance({ first: 0 })
//                 let currentNumbers = []
//                 while(currentNumbers.length < 6){
//                     let drawTransaction = await instance.processDraw()
//                     currentNumbers = drawTransaction.logs.filter(l => l.event == 'NumberWasDrawed')
//                         .reduce((arr, c) => arr.concat([Number(c.args.number)]), currentNumbers)
//                 }
//                 assert(true)
//             })                    
    })
})





    // describe("when checking winners", function() {
    //     it("should announce a winning ticket", async function() {
    //         let instance = await newInstance({ price: 100 })
    //         await instance.buyTicket([10, 20, 30, 40, 50, 60], { from: accounts[0], value: 100 })
    //         let checkWinnersTransaction = await instance._checkWinners([10,20,30,40,50,60])
    //         assert.equal(checkWinnersTransaction.logs.filter(l => l.event == 'AnnounceWinner').map(l => l.args).length, 1)
    //     })
    //     it("should be in the winners array", async function() {
    //         let instance = await newInstance({ price: 100 })
    //         await instance.buyTicket([10, 20, 30, 40, 50, 60], { from: accounts[0], value: 100 })
    //         await instance._checkWinners([10,20,30,40,50,60])
    //         let winner = await instance.winningTickets.call(0)
    //         assert.equal(1, Number(winner))
    //     })
    //     it("should not announce any winner", async function() {
    //         let instance = await newInstance({ price: 100 })
    //         await instance.buyTicket([11, 22, 33, 44, 56, 59], { from: accounts[0], value: 100 })
    //         let checkWinnersTransaction = await instance._checkWinners([10,20,30,40,50,60])
    //         assert.equal(checkWinnersTransaction.logs.filter(l => l.event == 'AnnounceWinner').map(l => l.args).length, 0)
    //     })
    //     it("should distribute prizes", async function() {
    //         let instance = await newInstance({ price: 100 })
    //         await instance.buyTicket([10, 20, 30, 40, 50, 60], { from: accounts[0], value: 100 })
    //         await instance.buyTicket([10, 20, 30, 40, 50, 60], { from: accounts[0], value: 100 })
    //         await instance.buyTicket([10, 20, 30, 40, 50, 59], { from: accounts[0], value: 100 })
    //         await instance.buyTicket([10, 19, 29, 39, 49, 59], { from: accounts[0], value: 100 })
    //         await instance.buyTicket([10, 20, 30, 40, 49, 59], { from: accounts[0], value: 100 })
    //         await instance.buyTicket([10, 20, 30, 40, 48, 59], { from: accounts[0], value: 100 })
    //         await instance.buyTicket([10, 20, 30, 40, 47, 59], { from: accounts[0], value: 100 })
    //         await instance.buyTicket([10, 19, 29, 39, 49, 59], { from: accounts[0], value: 100 })
    //         await instance.buyTicket([10, 19, 29, 39, 49, 59], { from: accounts[0], value: 100 })
    //         await instance.buyTicket([10, 19, 29, 39, 49, 59], { from: accounts[0], value: 100 })
    //         let checkWinnersTransaction = await instance._checkWinners([10,20,30,40,50,60])

    //         let prizes = checkWinnersTransaction.logs.filter(l => l.event == 'AnnouncePrize')
    //             .map(({args: { hits, numberOfWinners, prize }}) => ({ hits, numberOfWinners, prize }))
            
    //         assert.equal(prizes.find(p => p.hits == 4).numberOfWinners, 3)
    //         assert.equal(prizes.find(p => p.hits == 4).prize, 16)

    //         assert.equal(prizes.find(p => p.hits == 5).numberOfWinners, 1)
    //         assert.equal(prizes.find(p => p.hits == 5).prize, 150)

    //         assert.equal(prizes.find(p => p.hits == 6).numberOfWinners, 2)
    //         assert.equal(prizes.find(p => p.hits == 6).prize, 400)
    //     })
    //     it("should have money in my vault", async function() {
    //         let instance = await newInstance({ price: 100 })
    //         await instance.buyTicket([10, 20, 30, 40, 50, 60], { from: accounts[0], value: 100 })
    //         await instance.buyTicket([10, 20, 30, 40, 50, 60], { from: accounts[1], value: 100 })
    //         await instance.buyTicket([10, 20, 30, 40, 50, 59], { from: accounts[2], value: 100 })
    //         await instance.buyTicket([10, 19, 29, 39, 49, 59], { from: accounts[0], value: 100 })
    //         await instance.buyTicket([10, 20, 30, 40, 49, 59], { from: accounts[1], value: 100 })
    //         await instance.buyTicket([10, 20, 30, 40, 48, 59], { from: accounts[2], value: 100 })
    //         await instance.buyTicket([10, 20, 30, 40, 47, 59], { from: accounts[0], value: 100 })
    //         await instance.buyTicket([10, 19, 29, 39, 49, 59], { from: accounts[1], value: 100 })
    //         await instance.buyTicket([10, 19, 29, 39, 49, 59], { from: accounts[2], value: 100 })
    //         await instance.buyTicket([10, 19, 29, 39, 49, 59], { from: accounts[0], value: 100 })
    //         await instance._checkWinners([10,20,30,40,50,60])

    //         assert.equal(416, await instance.vault.call(accounts[0]))
    //         assert.equal(416, await instance.vault.call(accounts[1]))
    //         assert.equal(166, await instance.vault.call(accounts[2]))
    //     })
    // })
// })