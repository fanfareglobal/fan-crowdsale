import expectThrow from "openzeppelin-solidity/test/helpers/expectThrow";

const FanCrowdsale = artifacts.require("FanCrowdsale");
const FanToken = artifacts.require("FAN");

contract('FanCrowdsale', function(accounts) {
  let Coin = 10**18;
  let instance;
  let token;

  let whitelistedInvestor = accounts[1];
  let foreignInvestor = accounts[2];

  beforeEach('Setup', async function() {
    // tokenInstance = await FanToken.deployed();
    instance = await FanCrowdsale.deployed();
    token    = FanToken.at(await instance.token.call());

    // give crowdsale minting permission to token contract
    let tokenOwner = await token.owner.call();
    console.log("crowdsale contract address: " + instance.address);
    console.log("token contract address: " + token.address);
    console.log("token owner", tokenOwner);
    if (tokenOwner != instance.address) {
      await token.transferOwnership(instance.address);
      console.log('change owner: ', instance.address);
    }

    return true
  })

  it('should have correct initial variables', async function () {
    assert.equal(await instance.totalStages.call(), 5);
    assert.equal(await instance.currentStage.call(), 0);
    assert.equal(await instance.currentRate.call(), 12500 * Coin);
  })


  it('should not be finalized by default', async function () {
    assert.isFalse(await instance.isFinalized.call());
  })

  it('whitelist required', async function(){
    let tx = instance.sendTransaction({ from: foreignInvestor, value: web3.toWei(0.1, "ether")})
    await expectThrow(tx);
  });

  it('whitelist check', async function(){
    // add whitelistedInvestor to whitelist
    await instance.addAddressToWhitelist(whitelistedInvestor);
    assert.isTrue(await instance.whitelist(whitelistedInvestor));
    assert.isFalse(await instance.whitelist(foreignInvestor))
  });

  it('contribute 0.03 total', async function(){
    // add whitelistedInvestor to whitelist
    await instance.addAddressToWhitelist(whitelistedInvestor);
    // contribute 0.01
    let tx = await instance.sendTransaction({ from: whitelistedInvestor, value: web3.toWei(0.01, "ether")});
    let tokenAmount = await token.balanceOf(whitelistedInvestor);
    assert.equal(tokenAmount.toNumber(), 12500 * 0.01 * Coin, 'The sender didn\'t receive the tokens as per stage0 rate');

    // contribute more 0.02
    tx = await instance.sendTransaction({ from: whitelistedInvestor, value: web3.toWei(0.02, "ether")});
    tokenAmount = await token.balanceOf(whitelistedInvestor);
    assert.equal(tokenAmount.toNumber(), 12500 * (0.01+0.02) * Coin, 'The sender didn\'t receive the tokens as per stage0 rate');

  });

  it('contribute 0.1 to cross stage from 0 to 1', async function(){
    // foundation wallet initial balance
    let initialTokenAmount = await token.balanceOf(whitelistedInvestor);
    let foundationWallet = await instance.wallet.call()
    let initialWalletBalance = await web3.eth.getBalance(foundationWallet);

    let tx = await instance.sendTransaction({ from: whitelistedInvestor, value: web3.toWei(0.1, "ether")});

    // should receive 1220 token (12500 * 0.07 + 11500 * 0.03)
    let tokenAmount = await token.balanceOf(whitelistedInvestor);
    let tokenPurchased = tokenAmount - initialTokenAmount;
    assert.equal(tokenPurchased, 1220 * Coin, "contributor does not receive correct amount of token");

    // should proceed to next stage
    assert.equal((await instance.currentStage.call()).toNumber(), 1, 'crowdsale does not proceed to next stage');
    assert.equal((await instance.currentRate.call()).toNumber(), 11500 * Coin, 'crowdsale does not have correct rate adjusted');

    // foundation wallet should have 0.1 eth increase
    let newBalance = web3.eth.getBalance(foundationWallet);
    let increasedBalance = newBalance - initialWalletBalance;
    assert.equal(increasedBalance, 0.1 * Coin, "foundation wallet doesn't obtain correct eth");
  })

  //0.37 should go through and 0.03 should refund
  //should receive 3955 (5550 - 12500*0.1 - 11500 * 0.03)
  ///*
  it('contribute 0.4 to finish the crowdsale', async function(){
    let startEthBalance = await web3.eth.getBalance(whitelistedInvestor);
    let startTokenBalance = await token.balanceOf(whitelistedInvestor);
    let foundationWallet = await instance.wallet.call()
    let startFoundationEthBalance = await web3.eth.getBalance(foundationWallet);

    // contribute 0.4
    let tx = await instance.sendTransaction({ from: whitelistedInvestor, value: web3.toWei(0.4, "ether")});

    // should receive 3955 token
    let tokenAmount = await token.balanceOf(whitelistedInvestor);
    let tokenIncrease = tokenAmount - startTokenBalance;
    console.log(tokenAmount,'tokenAmount');
    console.log(startTokenBalance, 'startTokenBalance');
    console.log(tokenIncrease, 'tokenIncrease');
    // assert.equal(tokenIncrease, 3955 * Coin, 'The sender didn\'t receive the tokens as per stage0 rate');

    // 0.03 should refund
    let endEthBalance = await web3.eth.getBalance(whitelistedInvestor);
    let ethSpent = endEthBalance - startEthBalance;
    assert.equal(ethSpent, 0.37 * Coin, "contributor should only spent 0.37 eth");

    // foundation should receive 0.37
    let endFoundationEthBalance = await web3.eth.getBalance(foundationWallet);
    let ethIncrease = endFoundationEthBalance - startFoundationEthBalance;
    assert.equal(ethIncrease, 0.37 * Coin, "foundation wallet should receive 0.37 eth");

    // crowdsale should finish
    // TODO: check contract is finished
  })
  //*/

});