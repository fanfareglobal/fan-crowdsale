pragma solidity ^0.4.24;

/**
 * @title Withdrawable
 * @dev Allow contract owner to withdrow Ether or ERC20 token from contract.
 *
 */
contract Withdrawable is Ownable {
    /**
    * @dev withdraw Ether from contract
    * @param _to The address transfer Ether to.
    * @param _value The amount to be transferred.
    */
    function withdrawEther(address _to, uint _value) onlyOwner public returns(bool) {
        require(_to != address(0));
        require(address(this).balance >= _value);

        _to.transfer(_value);

        return true;
    }

    /**
    * @dev withdraw ERC20 token from contract
    * @param _token ERC20 token contract address.
    * @param _to The address transfer Token to.
    * @param _value The amount to be transferred.
    */
    function withdrawTokens(ERC20 _token, address _to, uint _value) onlyOwner public returns(bool) {
        require(_to != address(0));

        return _token.transfer(_to, _value);
    }
}