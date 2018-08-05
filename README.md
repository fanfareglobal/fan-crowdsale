# Deployment Notes

## Rinkeby

    truffle compile
    truffle migrate --network rinkeby --reset
    truffle networks # check for contract addresses for crowdsale and token
    
    truffle console --network rinkeby

**Change token controller/owner to crowdsale contract**

    token = FAN.at(*token_address*)
    token.transferOwnership(*crowdsale_address*)
    
**Add whitelisted user**

    instance = FanCrowdsale.at(*crowdsale_address*)
    instance.addAddressToWhitelist(*contributor*)
    
**Send eth from *contributor* address**