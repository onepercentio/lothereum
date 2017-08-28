pragma solidity ^0.4.11;


/**
 * @title Migrations
 * @dev This is a truffle contract, needed for truffle integration, not meant for use by Zeppelin users.
 */
contract Migrations {
  uint256 public lastCompletedMigration;

  function setCompleted(uint256 completed) {
    lastCompletedMigration = completed;
  }

  function upgrade(address newAddress) {
    Migrations upgraded = Migrations(newAddress);
    upgraded.setCompleted(lastCompletedMigration);
  }
}
