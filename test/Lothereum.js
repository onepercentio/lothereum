'use strict';

// imports
const assertJump = require('./helpers/assertJump');
import ether from './helpers/ether';
import { advanceBlock } from './helpers/advanceToBlock';
import { increaseTimeTo, duration } from './helpers/increaseTime';
import latestTime from './helpers/latestTime';
import EVMThrow from './helpers/EVMThrow';

const BigNumber = web3.BigNumber;

const should = require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should();
var Lothereum = artifacts.require('Lothereum');

// constants
const DEFAULT_NAME = 'MEGA SENA';
const DEFAULT_PRICE = 35000;
const firstDate = Math.round(new Date() / 1000) + 6000;
const newInstance = (
    {
        name = DEFAULT_NAME,
        interval = [60],
        first = firstDate,
        n = 6,
        max = 60,
        price = DEFAULT_PRICE,
        distribution = [0, 0, 0, 5, 15, 80],
        blockInterval = 8
    } = {}
) => Lothereum.new(name, interval, first, n, max, price, distribution, blockInterval)

// tests
contract('Lothereum', function(accounts) {

    before(async function() {
        //Advance to the next block to correctly read time in the solidity "now" function interpreted by testrpc
        await advanceBlock();
    });

    describe('Deployment', function() {
        it('should create the contract with correct conditions', async function() {
            let lothereum = await newInstance();

            let name = await lothereum.name();
            assert.isTrue(DEFAULT_NAME === name);
        });

        it('should not create contract with invalid interval (.length not in (1 - 99))', async function() {
            await newInstance({
                interval: []
            }).should.be.rejectedWith(EVMThrow);
        });

        it('should not create contract with invalid interval (value < 60)', async function() {
            await newInstance({
                interval: [59]
            }).should.be.rejectedWith(EVMThrow);
        });

        it('should not create contract with invalid first drawing date (< now)', async function() {
            await newInstance({
                first: 0
            }).should.be.rejectedWith(EVMThrow);
        });

        it('should not create contract with invalid numbers per ticket (1 - 50)', async function() {
            await newInstance({
                n: 0
            }).should.be.rejectedWith(EVMThrow);

            await newInstance({
                n: 51
            }).should.be.rejectedWith(EVMThrow);
        });

        it('should not create contract with invalid maximum drawable number (1 - 65534)', async function() {
            await newInstance({
                max: 0
            }).should.be.rejectedWith(EVMThrow);

            await newInstance({
                max: 65535
            }).should.be.rejectedWith(EVMThrow);
        });

        it('should not create contract with invalid price (> 0)', async function() {
            await newInstance({
                price: 0
            }).should.be.rejectedWith(EVMThrow);
        });

        it('should not create contract with invalid prize distribution rule (.length != numbers per ticket)', async function() {
            await newInstance({
                distribution: [0]
            }).should.be.rejectedWith(EVMThrow);
        });

        it('should not create contract with invalid prize distribution percentage (sum != 100%)', async function() {
            await newInstance({
                distribution: [0, 0, 0, 0, 0, 99]
            }).should.be.rejectedWith(EVMThrow);
        });

        it('should not create contract with wrong conditions (# per ticket >= max #)', async function() {
            await newInstance({
                n: 5,
                max: 5
            }).should.be.rejectedWith(EVMThrow);
        });

        it('should not create contract with invalid block interval (< 8)', async function() {
            await newInstance({
                blockInterval: 7
            }).should.be.rejectedWith(EVMThrow);
        });

        it('should not allow direct transaction', async function() {
            let lothereum = await newInstance();
            await lothereum.send(1).should.be.rejectedWith(EVMThrow);
        });

    });

    describe('Buying a ticket', function() {

        var lothereum;
        var numbers = [1, 2, 3, 4, 5, 6];
        var numbers1 = [6, 7, 8, 9, 10, 11];

        before(async function() {
            lothereum = await newInstance();
        });

        it('should allow with correct data + (total prize sum + map numbers)', async function() {
            const { logs } = await lothereum.buyTicket(
                numbers,
                {
                    value: DEFAULT_PRICE,
                    from: accounts[1]
                })
            const event = logs.find(e => e.event === 'NewTicket');

            should.exist(event);

            event.args.holder.should.equal(accounts[1])
            event.args.drawingNumber.should.be.bignumber.equal(1)
            event.args.ticketId.should.be.bignumber.equal(1)
            for (let i = 0; i < event.args.numbers.length; i++) (new BigNumber(event.args.numbers[i])).should.be.bignumber.equal(numbers[i])

            Number((await lothereum.draws(1))[1]).should.be.equal(DEFAULT_PRICE);

            await lothereum.buyTicket(
                numbers1,
                {
                    value: DEFAULT_PRICE,
                    from: accounts[2]
                })
            let allNumbers = numbers.concat(numbers1)
            for (let i = 0; i < allNumbers.length; i++) {
                if (allNumbers[i] < 6) {
                    Number((await lothereum.numbersMap(1, allNumbers[i]))[0]).should.be.equal(1)
                } else if (allNumbers[i] == 6) {
                    Number((await lothereum.numbersMap(1, allNumbers[i]))[0]).should.be.equal(1)
                    Number((await lothereum.numbersMap(1, allNumbers[i]))[1]).should.be.equal(2)
                } else {
                    Number((await lothereum.numbersMap(1, allNumbers[i]))[0]).should.be.equal(2)
                }
            }
        });

        it('should not allow wrong price', async function() {
            await lothereum.buyTicket(numbers, {value: 1, from: accounts[1]}).should.be.rejectedWith(EVMThrow);
        });

        it('should not allow disordened numbers i.e [3,2,1]', async function() {
            await lothereum.buyTicket([3, 2, 1, 4, 5, 6], {value: DEFAULT_PRICE, from: accounts[1]}).should.be.rejectedWith(EVMThrow);
        });

        it('should not allow repeated numbers i.e [3,2,3]', async function() {
            await lothereum.buyTicket([1, 2, 3, 4, 5, 5], {value: DEFAULT_PRICE, from: accounts[1]}).should.be.rejectedWith(EVMThrow);
        });

        it('should not allow numbers on ticket != numbers per ticket', async function() {
            await lothereum.buyTicket([1, 2], {value: DEFAULT_PRICE, from: accounts[1]}).should.be.rejectedWith(EVMThrow);
        });

        describe('New drawing time', function() {
            it('should buy ticket to the next drawing', async function() {
                await lothereum.buyTicket(numbers, {value: DEFAULT_PRICE, from: accounts[1]}).should.be.fulfilled;
            });
        });

    });
});
