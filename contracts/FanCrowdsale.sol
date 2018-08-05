pragma solidity ^0.4.24;

import './FAN.sol';
import './Withdrawable.sol';
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/AddressUtils.sol";
import 'openzeppelin-solidity/contracts/lifecycle/Pausable.sol';
import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';
import 'openzeppelin-solidity/contracts/access/Whitelist.sol';


contract FanCrowdsale is Ownable, Pausable, Whitelist, Withdrawable {
  using SafeMath for uint256;
  using AddressUtils for address;

  // helper with wei
  uint256 constant Coin = 1 ether;

  // token
  FAN public token;

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

  // Token Cap/Goal
  // =============================
  uint256 public totalTokensForSale; // = 424000000 * Coin; // tokens be sold in Crowdsale
  uint256 public goalInToken;        // min token to sale
  // ==============================

  // Finalize
  // =============================
  bool public isFinalized = false;
  event Finalized();
  // ==============================

  event DLog(uint num);


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

    // make sure this crowdsale contract has ability to mint
    // make sure token's mint authority has me
    // yet fan token contract doesn't expose a public check func
    // must manually make sure crowdsale contract address is added
    // to authorities of token contract
    // require(_token.controller() == address(this));

    token  = FAN(_token);
    wallet = _wallet;

    openingTime = _startTime;
    closingTime = _endTime;

    totalTokensForSale  = _cap;
    goalInToken = 0; // we don't need that feature, so give it 0 to override

    _initStages();
    _setCrowdsaleStage(0);
  }
  // =============

  // Crowdsale Stage Management
  // =========================================================
  // Change Crowdsale Stage. Available Options: 0..4
  function _setCrowdsaleStage(uint8 _stageId) internal {
    require(_stageId >= 0);
    require(totalStages > _stageId);

    currentStage = _stageId;
    currentRate = stages[_stageId].rate;

    currentStageWeiRaised = 0;
    currentStageTokensSold = 0;
  }

  function _initStages() internal {
    // production setting
    // stages[0] = Stage(25000000 * Coin, 12500 * Coin);
    // stages[1] = Stage(46000000 * Coin, 11500 * Coin);
    // stages[2] = Stage(88000000 * Coin, 11000 * Coin);
    // stages[3] = Stage(105000000 * Coin, 10500 * Coin);
    // stages[4] = Stage(160000000 * Coin, 10000 * Coin);

    // development setting
    // 0.1 ETH allocation per stage for faster forward test
    stages[0] = Stage(1250 * Coin, 12500 * Coin);
    stages[1] = Stage(1150 * Coin, 11500 * Coin);
    stages[2] = Stage(1100 * Coin, 11000 * Coin);
    stages[3] = Stage(1050 * Coin, 10500 * Coin);
    stages[4] = Stage(1000 * Coin, 10000 * Coin);

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
    require(_buyer != address(0));
    require(!_buyer.isContract());
    // double check not to over sell
    require(totalTokensSold < totalTokensForSale);

    uint256 tokensToMint = _getTokenAmount(_weiAmount);

    emit DLog(_weiAmount);

    // temp var
    uint256 saleableTokens;
    uint256 acceptedWei;

    // if exceed totalTokensForSale
    if (totalTokensSold.add(tokensToMint) > totalTokensForSale) {
      // accept partial
      saleableTokens = totalTokensForSale.sub(totalTokensSold);
      acceptedWei = saleableTokens.mul(Coin).div(currentRate);

      _buyTokens(_buyer, acceptedWei);

      // return the excess
      _buyer.transfer(_weiAmount.sub(acceptedWei));
      emit EthRefunded("Exceed Total Token Distributed");
    } else {
      // cross two stages
      if (currentStageTokensSold.add(tokensToMint) > stages[currentStage].tokenAllocated) {
        saleableTokens = stages[currentStage].tokenAllocated.sub(currentStageTokensSold);
        acceptedWei = saleableTokens.mul(Coin).div(currentRate);
        emit DLog(acceptedWei);

        // buy first stage partial
        _buyTokens(_buyer, acceptedWei);

        // buy next stage for the rest
        // _buyTokens(_buyer, _weiAmount.sub(acceptedWei));
        contribute(_buyer, _weiAmount.sub(acceptedWei));
      } else {
        // normal situation
        _buyTokens(_buyer, _weiAmount);
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

    _finalization();
    emit Finalized();

    isFinalized = true;
  }
  // ===============================


  // -----------------------------------------
  // Internal interface (extensible)
  // -----------------------------------------

  /**
   * @dev perform buyTokens action for buyer
   * @param buyer Address performing the token purchase
   * @param weiAmount Value in wei involved in the purchase
   */
  function _buyTokens(address buyer, uint weiAmount) internal {
    _preValidatePurchase(buyer, weiAmount);

    uint256 tokens = _getTokenAmount(weiAmount);

    currentStageWeiRaised = currentStageWeiRaised.add(weiAmount);
    currentStageTokensSold = currentStageTokensSold.add(tokens);

    totalWeiRaised = totalWeiRaised.add(weiAmount);
    totalTokensSold = totalTokensSold.add(tokens);

    // mint tokens to buyer's account
    _processPurchase(buyer, tokens);
    emit TokenPurchase(
      buyer,
      weiAmount,
      tokens
    );

    // // update stage stage etc
    _updatePurchasingState(buyer, weiAmount);

    // // move ether to foundation wallet
    _forwardFunds(weiAmount);

    // check after state
    _postValidatePurchase(buyer, weiAmount);
  }

  /**
   * @dev Validation of an incoming purchase. Use require statements to revert state when conditions are not met. Use super to concatenate validations.
   * @param _beneficiary Address performing the token purchase
   * @param _weiAmount Value in wei involved in the purchase
   */
  function _preValidatePurchase(
    address _beneficiary,
    uint256 _weiAmount
  )
    onlyIfWhitelisted(_beneficiary)
    view internal
  {
    require(_beneficiary != address(0));
    require(_weiAmount != 0);
  }

  /**
   * @dev Validation of an executed purchase. Observe state and use revert statements to undo rollback when valid conditions are not met.
   * @param _beneficiary Address performing the token purchase
   * @param _weiAmount Value in wei involved in the purchase
   */
  function _postValidatePurchase(
    address _beneficiary,
    uint256 _weiAmount
  )
    view internal
  {
    // optional override
  }

  /**
   * @dev Source of tokens. Override this method to modify the way in which the crowdsale ultimately gets and sends its tokens.
   * @param _beneficiary Address performing the token purchase
   * @param _tokenAmount Number of tokens to be emitted
   */
  function _deliverTokens(
    address _beneficiary,
    uint256 _tokenAmount
  )
    internal
  {
    // token.safeTransfer(_beneficiary, _tokenAmount);
    token.mint(_beneficiary, _tokenAmount);
  }

  /**
   * @dev Executed when a purchase has been validated and is ready to be executed. Not necessarily emits/sends tokens.
   * @param _beneficiary Address receiving the tokens
   * @param _tokenAmount Number of tokens to be purchased
   */
  function _processPurchase(
    address _beneficiary,
    uint256 _tokenAmount
  )
    internal
  {
    _deliverTokens(_beneficiary, _tokenAmount);
  }

  /**
   * @dev Override for extensions that require an internal state to check for validity (current user contributions, etc.)
   * @param _beneficiary Address receiving the tokens
   * @param _weiAmount Value in wei involved in the purchase
   */
  function _updatePurchasingState(
    address _beneficiary,
    uint256 _weiAmount
  )
    onlyWhileOpen
    internal
  {
    if (currentStageTokensSold >= stages[currentStage].tokenAllocated) {
      _setCrowdsaleStage(currentStage + 1);
    }
  }

  /**
   * @dev Override to extend the way in which ether is converted to tokens.
   * @param _weiAmount Value in wei to be converted into tokens
   * @return Number of tokens that can be purchased with the specified _weiAmount
   */
  function _getTokenAmount(uint256 _weiAmount)
    internal view returns (uint256)
  {
    return _weiAmount.mul(currentRate).div(Coin);
  }

  /**
   * @dev forward raised eth to wallet
   */
  function _forwardFunds(uint _weiAmount) internal {
    wallet.transfer(_weiAmount);
    emit EthTransferred("forwarding funds to wallet");
  }

  /**
   * @dev perform finalization work, check if crowdsale is successful or not to
   * determine whether to refund
   */
  function _finalization() internal {
    // goal not reached
    if (totalTokensSold < goalInToken) {
      // we do refund
      _refund();
    }
  }

  /**
   * @dev refund raised eth to contributors
   */
  function _refund() internal {
    // TODO: to be implemented
  }
}