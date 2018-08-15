pragma solidity ^0.4.24;

import './MintableERC20.sol';
import 'openzeppelin-solidity/contracts/token/ERC20/ERC20.sol';
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/AddressUtils.sol";
import 'openzeppelin-solidity/contracts/lifecycle/Pausable.sol';
import 'openzeppelin-solidity/contracts/access/Whitelist.sol';


contract FanCrowdsale is Pausable {
  using SafeMath for uint256;
  using AddressUtils for address;

  // helper with wei
  uint256 constant COIN = 1 ether;

  // token
  MintableERC20 public mintableToken;

  // wallet to hold funds
  address public wallet;

  Whitelist public whitelist;

  // Stage
  // ============
  struct Stage {
    uint tokenAllocated;
    uint rate;
  }

  uint8 public currentStage;
  mapping (uint8 => Stage) public stages;
  uint8 public totalStages; //stages count

  // Amount raised
  // ==================
  uint256 public totalTokensSold;
  uint256 public totalWeiRaised;

  // timed
  // ======
  uint256 public openingTime;
  uint256 public closingTime;

  /**
   * @dev Reverts if not in crowdsale time range.
   */
  modifier onlyWhileOpen {
    require(block.timestamp >= openingTime && !hasClosed());
    _;
  }

  // Token Cap
  // =============================
  uint256 public totalTokensForSale; // = 424000000 * COIN; // tokens be sold in Crowdsale

  // Finalize
  // =============================
  bool public isFinalized = false;


  // Constructor
  // ============
  /**
   * @dev constructor
   * @param _token token contract address
   * @param _startTime start time of crowdscale
   * @param _endTime end time of crowdsale
   * @param _wallet foundation/multi-sig wallet to store raised eth
   * @param _cap max eth to raise in wei
   */
  constructor(
    address _token,
    uint256 _startTime,
    uint256 _endTime,
    address _wallet,
    uint256 _cap) public
  {
    require(_wallet != address(0), "need a good wallet to store fund");
    require(_token != address(0), "token is not deployed?");
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

    // require that the sum of the stages is equal to the totalTokensForSale, _cap is for double check
    require(stages[totalStages - 1].tokenAllocated == totalTokensForSale);
    
  }
  // =============

  // fallback
  function () external payable {
    contribute(msg.sender, msg.value);
  }
  
  // Token Purchase
  // =========================
  /**
   * @dev crowdsale must be open and we do not accept contribution sent from contract
   * because we credit tokens back it might trigger problem, eg, from exchange withdraw contract
   */
  function contribute(address _buyer, uint256 _weiAmount) public payable whenNotPaused onlyWhileOpen {
    require(_buyer != address(0));
    require(!_buyer.isContract());
    require(whitelist.whitelist(_buyer));

    // double check not to over sell
    require(totalTokensSold < totalTokensForSale);

    uint currentRate = stages[currentStage].rate;
    uint256 tokensToMint = _weiAmount.mul(currentRate);

    // refund excess
    uint256 saleableTokens;
    uint256 acceptedWei;
    if (currentStage == (totalStages - 1) && totalTokensSold.add(tokensToMint) > totalTokensForSale) {
      saleableTokens = totalTokensForSale - totalTokensSold;
      acceptedWei = saleableTokens.div(currentRate);

      _buyTokensInCurrentStage(_buyer, acceptedWei, saleableTokens);

      // return the excess
      uint256 weiToRefund = _weiAmount.sub(acceptedWei);
      _buyer.transfer(weiToRefund);
      emit EthRefunded(_buyer, weiToRefund);
    } else if (totalTokensSold.add(tokensToMint) < stages[currentStage].tokenAllocated) {
      _buyTokensInCurrentStage(_buyer, _weiAmount, tokensToMint);
    } else {
      // cross stage yet within cap
      saleableTokens = stages[currentStage].tokenAllocated.sub(totalTokensSold);
      acceptedWei = saleableTokens.div(currentRate);

      // buy first stage partial
      _buyTokensInCurrentStage(_buyer, acceptedWei, saleableTokens);

      // update stage
      if (totalTokensSold >= stages[currentStage].tokenAllocated && currentStage + 1 < totalStages) {
        _setCrowdsaleStage(currentStage + 1);
      }

      // buy next stage for the rest
      contribute(_buyer, _weiAmount.sub(acceptedWei));
    }
  }

  function changeWhitelist(address _newWhitelist) public onlyOwner {
    require(_newWhitelist != address(0));
    emit WhitelistTransferred(whitelist, _newWhitelist);
    whitelist = Whitelist(_newWhitelist);
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


  // -----------------------------------------
  // Internal interface (extensible)
  // -----------------------------------------

  // Crowdsale Stage Management
  // =========================================================
  // Change Crowdsale Stage. Available Options: 0..4
  function _setCrowdsaleStage(uint8 _stageId) internal {
    require(_stageId >= 0 && _stageId < totalStages);

    currentStage = _stageId;

    emit StageUp(_stageId);
  }

  function _initStages() internal {
    // production setting
    // stages[0] = Stage(25000000 * COIN, 12500);
    // stages[1] = Stage(stages[0].tokenAllocated + 46000000 * COIN, 11500);
    // stages[2] = Stage(stages[1].tokenAllocated + 88000000 * COIN, 11000);
    // stages[3] = Stage(stages[2].tokenAllocated + 105000000 * COIN, 10500);
    // stages[4] = Stage(stages[3].tokenAllocated + 160000000 * COIN, 10000);

    // development setting
    // 0.1 ETH allocation per stage for faster forward test
    stages[0] = Stage(1250 * COIN,                            12500);    // 1 Ether(wei) = 12500 Coin(wei)
    stages[1] = Stage(stages[0].tokenAllocated + 1150 * COIN, 11500);
    stages[2] = Stage(stages[1].tokenAllocated + 1100 * COIN, 11000);
    stages[3] = Stage(stages[2].tokenAllocated + 1050 * COIN, 10500);
    stages[4] = Stage(stages[3].tokenAllocated + 1000 * COIN, 10000);

    totalStages = 5;
  }

  /**
   * @dev perform buyTokens action for buyer
   * @param _buyer Address performing the token purchase
   * @param _weiAmount Value in wei involved in the purchase
   */
  function _buyTokensInCurrentStage(address _buyer, uint _weiAmount, uint _tokenAmount) internal {
    // emit DLog(weiAmount, '_buyTokens');
    require(_buyer != address(0));
    require(_weiAmount != 0);

    totalWeiRaised = totalWeiRaised.add(_weiAmount);
    totalTokensSold = totalTokensSold.add(_tokenAmount);

    // mint tokens to buyer's account
    mintableToken.mint(_buyer, _tokenAmount);
    wallet.transfer(_weiAmount);

    emit TokenPurchase(_buyer, _weiAmount, _tokenAmount);
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
  event StageUp(uint8 stageId);

  event EthRefunded(address indexed buyer, uint256 value);

  event TokenPurchase(address indexed purchaser, uint256 value, uint256 amount);

  event WhitelistTransferred(address indexed previousWhitelist, address indexed newWhitelist);

  event ClaimedTokens(address indexed _token, address indexed _to, uint _amount);

  event Finalized();

  // debug log event
  event DLog(uint num, string msg);
}