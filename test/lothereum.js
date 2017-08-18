var Lothereum = artifacts.require("./Lothereum.sol");
const newInstance = ({interval = [1000], first = 1000, n = 6, max = 60, price = 100}) =>
    Lothereum.new(interval, first, n, max, price)

contract('The Lothereum contract', (accounts) => {
    it("should create a lottery with my started drawing definitions", async function() {
        let instance = await newInstance({ first: 501 })

        assert.equal(await instance.nextDrawing(), 501)
    })
    it("should correctly set next drawing", async function() {
        let instance = await newInstance({})
        await instance.setNextDrawing()
        
        assert.equal(await instance.nextDrawing(), 2000)
        assert.equal(await instance.nextDrawingIndex(), 0)
    })
    it("should increment next drawing index", async function() {
        let instance = await newInstance({ interval: [ 500, 700 ], first: 300})
        await instance.setNextDrawing()
        assert.equal(await instance.nextDrawing(), 800)
        assert.equal(await instance.nextDrawingIndex(), 1)

        await instance.setNextDrawing()
        assert.equal(await instance.nextDrawing(), 1500)
        assert.equal(await instance.nextDrawingIndex(), 0)
    })
    describe('when validating ticket numbers', function() {
        it("should check if the array is ordered and the maxnumber is respected", async function() {
            let instance = await newInstance({})
            assert.equal(true, await instance.areValidNumbers.call([1,2,3,4], 4))
        })
        it("should invalidate for number > maxnumber", async function() {
            let instance = await newInstance({})
            assert.equal(false, await instance.areValidNumbers.call([2], 1))
        })
        it("should invalidate for unordered array", async function() {
            let instance = await newInstance({})
            assert.equal(false, await instance.areValidNumbers.call([3,2,1], 60))
        })
        it("should invalidate with two equal values", async function() {
            let instance = await newInstance({})
            assert.equal(false, await instance.areValidNumbers.call([3,3,4], 60))
        })
        it("should invalidate a crazy array", async function() {
            let instance = await newInstance({})
            assert.equal(false, await instance.areValidNumbers.call([1,3,5,5,9,31,20], 25))
        })
    })
    describe('when buying a ticket', function() {
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
})



// var MetaCoin = artifacts.require("./MetaCoin.sol");

// contract('MetaCoin', function(accounts) {
//   it("should put 10000 MetaCoin in the first account", function() {
//     return MetaCoin.deployed().then(function(instance) {
//       return instance.getBalance.call(accounts[0]);
//     }).then(function(balance) {
//       assert.equal(balance.valueOf(), 10000, "10000 wasn't in the first account");
//     });
//   });
//   it("should call a function that depends on a linked library", function() {
//     var meta;
//     var metaCoinBalance;
//     var metaCoinEthBalance;

//     return MetaCoin.deployed().then(function(instance) {
//       meta = instance;
//       return meta.getBalance.call(accounts[0]);
//     }).then(function(outCoinBalance) {
//       metaCoinBalance = outCoinBalance.toNumber();
//       return meta.getBalanceInEth.call(accounts[0]);
//     }).then(function(outCoinBalanceEth) {
//       metaCoinEthBalance = outCoinBalanceEth.toNumber();
//     }).then(function() {
//       assert.equal(metaCoinEthBalance, 2 * metaCoinBalance, "Library function returned unexpected function, linkage may be broken");
//     });
//   });
//   it("should send coin correctly", function() {
//     var meta;

//     // Get initial balances of first and second account.
//     var account_one = accounts[0];
//     var account_two = accounts[1];

//     var account_one_starting_balance;
//     var account_two_starting_balance;
//     var account_one_ending_balance;
//     var account_two_ending_balance;

//     var amount = 10;

//     return MetaCoin.deployed().then(function(instance) {
//       meta = instance;
//       return meta.getBalance.call(account_one);
//     }).then(function(balance) {
//       account_one_starting_balance = balance.toNumber();
//       return meta.getBalance.call(account_two);
//     }).then(function(balance) {
//       account_two_starting_balance = balance.toNumber();
//       return meta.sendCoin(account_two, amount, {from: account_one});
//     }).then(function() {
//       return meta.getBalance.call(account_one);
//     }).then(function(balance) {
//       account_one_ending_balance = balance.toNumber();
//       return meta.getBalance.call(account_two);
//     }).then(function(balance) {
//       account_two_ending_balance = balance.toNumber();

//       assert.equal(account_one_ending_balance, account_one_starting_balance - amount, "Amount wasn't correctly taken from the sender");
//       assert.equal(account_two_ending_balance, account_two_starting_balance + amount, "Amount wasn't correctly sent to the receiver");
//     });
//   });
// });
