pragma solidity ^0.4.24;

import 'openzeppelin-solidity/contracts/token/ERC20/MintableToken.sol';

contract FAN is MintableToken {
  string public name = "Fan Token";
  string public symbol = "FAN";
  uint public decimals = 18;

  address public controller;
}