var FanCrowdsale = artifacts.require("./FanCrowdsale.sol");
var token = artifacts.require("./FAN.sol");

// console.log("network: " + NETWORK);
// console.log(global);

module.exports = function(deployer) {
  switch (deployer.chain) {
  case "development":
    deployOnLocal(deployer);
    break;

  case "rinkeby":
    deployOnRinkeby(deployer);
    break;

  case "live":
    deployOnMainnet(deployer);
    break;

  default:
    deployOnLocal(deployer);
    break;
  }
};

// configuation:
// https://docs.google.com/document/d/18Upg3bz4E_3nQAmIkW3OUxunSWU6CatyqLLMKG68ktE/edit
function deployOnMainnet(deployer){
  return deployer.deploy(FanCrowdsale,
    "0x90162f41886c0946d09999736f1c15c8a105a421",   //Fanfare token address
    1534492800,       // 2018-08-17 utc (2018-08-17 08:00 Singapore)
    1541030400,       // 2018-11-01 utc (2018-11-01 08:00 Singapore)
    "0xd4b2334ddb9d5468a4a330cd9f63f48f8aed0234", // foundation wallet
    424000000 * 10**18, // cap for crowdsale
    0                   // goal (set to 0 to ignore it)
  );
}

// deploy on local ganache private net
function deployOnLocal(deployer){
  // now + 10s
  const startTime = Math.round((new Date(Date.now() + 10000).getTime())/1000);
  // tomorrow
  const endTime = Math.round((new Date(Date.now() + 86400000).getTime())/1000);

  deployer.deploy(token).then(function(){
    return deployer.deploy(FanCrowdsale,
      token.address,
      startTime,
      endTime,
      "0x4e4Ece6430ba8B2dF490D3818973EC576B427DC0", // foundation wallet, test address in ganache， accounts[9]
      5550 * 10**18, // development setting: 1250 + 1150 + 1100 + 1050 + 1000 = 5550
      0
    );
  })
}

// rinkeby testnet
function deployOnRinkeby(deployer){
  // now + 10s
  const startTime = Math.round((new Date(Date.now() + 10000).getTime())/1000);
  // 7 days
  const endTime = Math.round((new Date(Date.now() + 86400000 * 7).getTime())/1000);

  deployer.deploy(token).then(function(){
    return deployer.deploy(FanCrowdsale,
      token.address,
      startTime,
      endTime,
      "0x169D6B29405e725947bE8A308a44F5918815D869", // foundation wallet, imtoken test address
      5550 * 10**18, // development setting: 1250 + 1150 + 1100 + 1050 + 1000 = 5550
      0
    );
  })
}