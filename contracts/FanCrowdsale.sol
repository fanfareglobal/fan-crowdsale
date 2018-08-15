pragma solidity ^0.4.24;

import './MintableERC20.sol';
import 'openzeppelin-solidity/contracts/token/ERC20/ERC20.sol';
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/AddressUtils.sol";
import 'openzeppelin-solidity/contracts/lifecycle/Pausable.sol';
import 'openzeppelin-solidity/contracts/access/Whitelist.sol';


contract FanCrowdsale is Pausable, Whitelist {
  using SafeMath for uint256;
  using AddressUtils for address;

  // helper with wei
  uint256 constant Coin = 1 ether;

  // token
  MintableERC20 public mintableToken;

  // wallet to hold funds
  address public wallet;

  // Stage
  // ============
  struct Stage {
    uint tokenAllocated;
    uint rate;
  }

  uint8 public currentStage;
  uint256 public currentRate;
  mapping (uint8 => Stage) public stages;
  uint8 public totalStages; //stages count
  event StageUp(uint8 stageId);
  // =============

  // Amount raised
  // ==================
  uint256 public totalTokensSold;
  uint256 public totalWeiRaised;
  uint256 public currentStageTokensSold;
  uint256 public currentStageWeiRaised;
  // ===================

  // Events
  event EthTransferred(string text);
  event EthRefunded(string text);
  /**
   * Event for token purchase logging
   * @param purchaser who paid for the tokens
   * @param value weis paid for purchase
   * @param amount amount of tokens purchased
   */
  event TokenPurchase(
    address indexed purchaser,
    uint256 value,
    uint256 amount
  );

  // timed
  // ======
  uint256 public openingTime;
  uint256 public closingTime;

  /**
   * @dev Reverts if not in crowdsale time range.
   */
  modifier onlyWhileOpen {
    // solium-disable-next-line security/no-block-members
    require(block.timestamp >= openingTime && block.timestamp <= closingTime && totalTokensSold < totalTokensForSale);
    _;
  }
  // ======

  // Token Cap
  // =============================
  uint256 public totalTokensForSale; // = 424000000 * Coin; // tokens be sold in Crowdsale
  // ==============================

  // Finalize
  // =============================
  bool public isFinalized = false;
  event Finalized();
  // ==============================

  // debug log event
  event DLog(uint num, string msg);


  // Constructor
  // ============
  /**
   * @dev constructor
   * @param _token token contract address
   * @param _startTime start time of crowdscale
   * @param _endTime end time of crowdsale
   * @param _wallet foundation/multi-sig wallet to store raised eth
   * @param _goal min eth to raise in wei, if goal is not reached, will trigger refund procedure
   * @param _cap max eth to raise in wei
   */
  constructor(
    address _token,
    uint256 _startTime,
    uint256 _endTime,
    address _wallet,
    uint256 _cap,
    uint256 _goal) public
  {
    require(_wallet != address(0), "need a good wallet to store fund");
    require(_token != address(0), "token is not deployed?");
    require(_goal <= _cap, "cap must be greater than goal");
    require(_goal >= 0, "must have a non-negative goal");
    // require(_startTime > block.timestamp, "startTime must be in future");
    require(_endTime > _startTime, "endTime must be greater than startTime");

    // make sure this crowdsale contract has ability to mint or make sure token's mint authority has me
    // yet fan token contract doesn't expose a public check func must manually make sure crowdsale contract address is added to authorities of token contract
    mintableToken  = MintableERC20(_token);
    wallet = _wallet;

    openingTime = _startTime;
    closingTime = _endTime;

    totalTokensForSale  = _cap;

    _initStages();
    _setCrowdsaleStage(0);
  }
  // =============

  // Crowdsale Stage Management
  // =========================================================
  // Change Crowdsale Stage. Available Options: 0..4
  function _setCrowdsaleStage(uint8 _stageId) internal {
    require(_stageId >= 0 && _stageId < totalStages);

    currentStage = _stageId;
    currentRate  = stages[_stageId].rate;

    currentStageWeiRaised  = 0;
    currentStageTokensSold = 0;

    emit StageUp(_stageId);
  }

  function _initStages() internal {
    // production setting
    // stages[0] = Stage(25000000 * Coin, 12500);
    // stages[1] = Stage(46000000 * Coin, 11500);
    // stages[2] = Stage(88000000 * Coin, 11000);
    // stages[3] = Stage(105000000 * Coin, 10500);
    // stages[4] = Stage(160000000 * Coin, 10000);

    // development setting
    // 0.1 ETH allocation per stage for faster forward test
    stages[0] = Stage(1250 * Coin, 12500);    // 1 Ether(wei) = 12500 Coin(wei)
    stages[1] = Stage(1150 * Coin, 11500);
    stages[2] = Stage(1100 * Coin, 11000);
    stages[3] = Stage(1050 * Coin, 10500);
    stages[4] = Stage(1000 * Coin, 10000);

    totalStages = 5;
  }

  // ================ Stage Management Over =====================

  // Token Purchase
  // =========================
  /**
   * @dev crowdsale must be open and we do not accept contribution sent from contract
   * because we credit tokens back it might trigger problem, eg, from exchange withdraw contract
   */
  function contribute(address _buyer, uint256 _weiAmount) public payable whenNotPaused onlyWhileOpen {
    // emit DLog(_weiAmount, 'contribute');
    // emit DLog(currentStage, 'currentStage');
    // emit DLog(currentStageTokensSold, 'currentStageTokensSold');

    require(_buyer != address(0));
    require(!_buyer.isContract());
    // double check not to over sell
    require(totalTokensSold < totalTokensForSale);

    uint256 tokensToMint = _weiAmount.mul(currentRate);

    // emit DLog(tokensToMint, 'tokensToMint');
    // emit DLog(totalTokensSold.add(tokensToMint), 'tokensToBeSold');

    // temp var
    uint256 saleableTokens;
    uint256 acceptedWei;

    // refund excess
    if (currentStage == (totalStages - 1) && totalTokensSold.add(tokensToMint) > totalTokensForSale) {
      saleableTokens = totalTokensForSale - totalTokensSold;
      acceptedWei = saleableTokens.div(currentRate);

      // emit DLog(saleableTokens, 'last saleableTokens');
      // emit DLog(acceptedWei, 'last acceptedWei');

      // // buy first stage partial
      _buyTokens(_buyer, acceptedWei);

      // // return the excess
      _buyer.transfer(_weiAmount.sub(acceptedWei));
      emit EthRefunded("Exceed Total Token Distributed: Refund");
    } else {
      // normal buy
      if (currentStageTokensSold.add(tokensToMint) <= stages[currentStage].tokenAllocated) {
        _buyTokens(_buyer, _weiAmount);
      } else {
        // cross stage yet within cap
        saleableTokens = stages[currentStage].tokenAllocated.sub(currentStageTokensSold);
        acceptedWei = saleableTokens.div(currentRate);
        // emit DLog(acceptedWei, 'acceptedWei');

        // buy first stage partial
        _buyTokens(_buyer, acceptedWei);

        // // buy next stage for the rest
        contribute(_buyer, _weiAmount.sub(acceptedWei));
      }
    }
  }

  // fallback
  function () external payable {
    contribute(msg.sender, msg.value);
  }

  /**
   * @dev Checks whether the period in which the crowdsale is open has already elapsed.
   * @return Whether crowdsale period has elapsed
   */
  function hasClosed() public view returns (bool) {
    // solium-disable-next-line security/no-block-members
    return block.timestamp > closingTime || totalTokensSold >= totalTokensForSale;
  }

  /**
   * @dev extend closing time to a future time
   */
  function extendClosingTime(uint256 _extendToTime) public onlyOwner onlyWhileOpen {
    closingTime = _extendToTime;
  }

  // ===========================

  // Finalize Crowdsale
  // ====================================================================

  function finalize() public onlyOwner {
    require(!isFinalized);
    require(hasClosed());

    emit Finalized();

    isFinalized = true;
  }
  // ===============================


  // -----------------------------------------
  // Internal interface (extensible)
  // -----------------------------------------

  /**
   * @dev perform buyTokens action for buyer
   * @param _buyer Address performing the token purchase
   * @param _weiAmount Value in wei involved in the purchase
   */
  function _buyTokens(address _buyer, uint _weiAmount) onlyIfWhitelisted(_buyer) internal {
    // emit DLog(weiAmount, '_buyTokens');
    require(_buyer != address(0));
    require(_weiAmount != 0);

    uint256 tokenAmount = _weiAmount.mul(currentRate);

    currentStageWeiRaised = currentStageWeiRaised.add(_weiAmount);
    currentStageTokensSold = currentStageTokensSold.add(tokenAmount);

    totalWeiRaised = totalWeiRaised.add(_weiAmount);
    totalTokensSold = totalTokensSold.add(tokenAmount);

    // mint tokens to buyer's account
    mintableToken.mint(_buyer, tokenAmount);

    emit TokenPurchase(_buyer, _weiAmount, tokenAmount);

    // update stage
    if (currentStageTokensSold >= stages[currentStage].tokenAllocated && currentStage + 1 < totalStages) {
      _setCrowdsaleStage(currentStage + 1);
    }

    // emit DLog(currentStageTokensSold, 'currentStageTokensSold');
    // emit DLog(stages[currentStage].tokenAllocated, 'currentStageTokenAllocated');

    // // move ether to foundation wallet
    wallet.transfer(_weiAmount);
    emit EthTransferred("forwarding funds to wallet");
  }


//////////
// Safety Methods
//////////

    /// @notice This method can be used by the controller to extract mistakenly
    ///  sent tokens to this contract.
    /// @param _token The address of the token contract that you want to recover
    ///  set to 0 in case you want to extract ether.
  function claimTokens(address _token) onlyOwner public {
      if (_token == 0x0) {
          owner.transfer(address(this).balance);
          return;
      }

      ERC20 token = ERC20(_token);
      uint balance = token.balanceOf(this);
      token.transfer(owner, balance);

      emit ClaimedTokens(_token, owner, balance);
  }

////////////////
// Events
////////////////

    event ClaimedTokens(address indexed _token, address indexed _to, uint _amount);
}