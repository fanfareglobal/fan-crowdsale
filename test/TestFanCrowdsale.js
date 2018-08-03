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
    console.log("crowdsale contract address: " + instance.address);
    console.log("token contract address: " + token.address);
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

  it('one ETH should buy 1250 Fan Tokens in stage 0', async function(){
    tx = await instance.sendTransaction({ from: whitelistedInvestor, value: web3.toWei(0.1, "ether")});
    tokenAmount = await token.balanceOf(whitelistedInvestor);
    assert.equal(tokenAmount.toNumber(), 1250 * Coin, 'The sender didn\'t receive the tokens as per stage0 rate');
  });

  // it('should deploy the token and store the address', async function(done){
  //   FanCrowdsale.deployed().then(async function(instance) {
  //     const token = await instance.token.call();
  //     assert(token, 'Token address couldn\'t be stored');
  //     done();
  //   });
  // });

  // it('should set stage to 0', function(done){
  //   FanCrowdsale.deployed().then(async function(instance) {
  //     const stage = await instance.currentStage.call();
  //     assert.equal(stage.toNumber(), 0, 'The stage couldn\'t be set to PreICO');
  //     done();
  //   });
  // });

  // it('one ETH should buy 5 Fan Tokens in stage 0', function(done){
  //   FanCrowdsale.deployed().then(async function(instance) {
  //     const data = await instance.sendTransaction({ from: accounts[7], value: web3.toWei(1, "ether")});
  //     const tokenAddress = await instance.token.call();
  //     const hashnodeToken = FanToken.at(tokenAddress);
  //     const tokenAmount = await hashnodeToken.balanceOf(accounts[7]);
  //     assert.equal(tokenAmount.toNumber(), 5000000000000000000, 'The sender didn\'t receive the tokens as per PreICO rate');
  //     done();
  //   });
  // });
  //
  // it('should transfer the ETH to wallet immediately in Pre ICO', function(done){
  //   FanCrowdsale.deployed().then(async function(instance) {
  //     let balanceOfBeneficiary = await web3.eth.getBalance(accounts[9]);
  //     balanceOfBeneficiary = Number(balanceOfBeneficiary.toString(10));
  //
  //     await instance.sendTransaction({ from: accounts[1], value: web3.toWei(2, "ether")});
  //
  //     let newBalanceOfBeneficiary = await web3.eth.getBalance(accounts[9]);
  //     newBalanceOfBeneficiary = Number(newBalanceOfBeneficiary.toString(10));
  //
  //     assert.equal(newBalanceOfBeneficiary, balanceOfBeneficiary + 2000000000000000000, 'ETH couldn\'t be transferred to the beneficiary');
  //     done();
  //   });
  // });
  //
  // it('should set variable `totalWeiRaisedDuringPreICO` correctly', function(done){
  //   FanCrowdsale.deployed().then(async function(instance) {
  //     var amount = await instance.totalWeiRaisedDuringPreICO.call();
  //     assert.equal(amount.toNumber(), web3.toWei(3, "ether"), 'Total ETH raised in PreICO was not calculated correctly');
  //     done();
  //   });
  // });
  //
  // it('should set stage to ICO', function(done){
  //   FanCrowdsale.deployed().then(async function(instance) {
  //     await instance.setCrowdsaleStage(1);
  //     const stage = await instance.stage.call();
  //     assert.equal(stage.toNumber(), 1, 'The stage couldn\'t be set to ICO');
  //     done();
  //   });
  // });
  //
  // it('one ETH should buy 2 Fan Tokens in ICO', function(done){
  //   FanCrowdsale.deployed().then(async function(instance) {
  //     const data = await instance.sendTransaction({ from: accounts[2], value: web3.toWei(1.5, "ether")});
  //     const tokenAddress = await instance.token.call();
  //     const hashnodeToken = FanToken.at(tokenAddress);
  //     const tokenAmount = await hashnodeToken.balanceOf(accounts[2]);
  //     assert.equal(tokenAmount.toNumber(), 3000000000000000000, 'The sender didn\'t receive the tokens as per ICO rate');
  //     done();
  //   });
  // });
  //
  // it('should transfer the raised ETH to RefundVault during ICO', function(done){
  //   FanCrowdsale.deployed().then(async function(instance) {
  //     var vaultAddress = await instance.vault.call();
  //
  //     let balance = await web3.eth.getBalance(vaultAddress);
  //
  //     assert.equal(balance.toNumber(), 1500000000000000000, 'ETH couldn\'t be transferred to the vault');
  //     done();
  //   });
  // });
  //
  // it('Vault balance should be added to our wallet once ICO is over', function(done){
  //   FanCrowdsale.deployed().then(async function(instance) {
  //     let balanceOfBeneficiary = await web3.eth.getBalance(accounts[9]);
  //     balanceOfBeneficiary = balanceOfBeneficiary.toNumber();
  //
  //     var vaultAddress = await instance.vault.call();
  //     let vaultBalance = await web3.eth.getBalance(vaultAddress);
  //
  //     await instance.finish(accounts[0], accounts[1], accounts[2]);
  //
  //     let newBalanceOfBeneficiary = await web3.eth.getBalance(accounts[9]);
  //     newBalanceOfBeneficiary = newBalanceOfBeneficiary.toNumber();
  //
  //     assert.equal(newBalanceOfBeneficiary, balanceOfBeneficiary + vaultBalance.toNumber(), 'Vault balance couldn\'t be sent to the wallet');
  //     done();
  //   });
  // });
});