/*
 * SET Token Smart Contract.  Copyright © 2018 by ABDK Consulting.
 * Author: Mikhail Vladimirov <mikhail.vladimirov@gmail.com>
 */
pragma solidity ^0.4.20;

import "./AbstractToken.sol";

/**
 * SET Token Smart Contract: EIP-20 compatible token smart contract that manages
 * SET tokens.
 */
contract SETToken is AbstractToken {
  /**
   * Maximum allowed number of tokens in circulation.
   */
  uint256 constant internal MAX_TOKENS_COUNT =
    0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

  /**
   * Transfer fee.
   */
  uint256 constant internal FEE = 5e2;

  /**
   * Create SET Token smart contract with message sender as an owner.
   *
   * @param _feeCollector address fees are sent to
   */
  function SETToken (address _feeCollector) public {
    owner = msg.sender;
    feeCollector = _feeCollector;
  }

  /**
   * Get name of the token.
   *
   * @return name of the token
   */
  function name () pure returns (string) {
    return "Stable Euro Token";
  }

  /**
   * Get symbol of the token.
   *
   * @return symbol of the token
   */
  function symbol () pure returns (string) {
    return "SET";
  }

  /**
   * Get number of decimals for the token.
   *
   * @return number of decimals for the token
   */
  function decimals () pure returns (uint8) {
    return 2;
  }

  /**
   * Get total number of tokens in circulation.
   *
   * @return total number of tokens in circulation
   */
  function totalSupply () public view returns (uint256) {
    return tokensCount;
  }
  /**
   * Transfer given number of tokens from message sender to given recipient.
   *
   * @param _to address to transfer tokens to the owner of
   * @param _value number of tokens to transfer to the owner of given address
   * @return true if tokens were transferred successfully, false otherwise
   */
  function transfer (address _to, uint256 _value)
  public returns (bool) {
    if (frozen) return false;
    else if (_value <= accounts [msg.sender] &&
            FEE <= safeSub (accounts [msg.sender], _value)) {
      require (AbstractToken.transfer (_to, _value));
      require (AbstractToken.transfer (feeCollector, FEE));
      return true;
    } else return false;
  }

  /**
   * Transfer given number of tokens from given owner to given recipient.
   *
   * @param _from address to transfer tokens from the owner of
   * @param _to address to transfer tokens to the owner of
   * @param _value number of tokens to transfer from given owner to given
   *        recipient
   * @return true if tokens were transferred successfully, false otherwise
   */
  function transferFrom (address _from, address _to, uint256 _value)
  public returns (bool) {
    if (frozen) return false;
    else if (_value <= allowances [_from][msg.sender] &&
            FEE <= safeSub (allowances [_from][msg.sender], _value) &&
            _value <= accounts [_from] &&
            FEE <= safeSub (accounts [_from], _value)) {
      require (AbstractToken.transferFrom (_from, _to, _value));
      require (AbstractToken.transferFrom (_from, feeCollector, FEE));
      return true;
    } else return false;
  }

  /**
   * Transfer given number of token from the signed defined by digital signature
   * to given recipient.
   *
   * @param _to address to transfer token to the owner of
   * @param _value number of tokens to transfer
   * @param _fee number of tokens to give to message sender
   * @param _nonce nonce of the transfer
   * @param _v parameter V of digital signature
   * @param _r parameter R of digital signature
   * @param _s parameter S of digital signature
   */
  function delegatedTransfer (
    address _to, uint256 _value, uint256 _fee,
    uint256 _nonce, uint8 _v, bytes32 _r, bytes32 _s)
  public returns (bool) {
    if (frozen) return false;
    else {
      address _from = ecrecover (
        keccak256 (
          thisAddress (), messageSenderAddress (), _to, _value, _fee, _nonce),
        _v, _r, _s);

      if (_nonce != nonces [_from]) return false;

      uint256 balance = accounts [_from];
      if (_value > balance) return false;
      balance = safeSub (balance, _value);
      if (FEE > balance) return false;
      balance = safeSub (balance, FEE);
      if (_fee > balance) return false;
      balance = safeSub (balance, _fee);

      nonces [_from] = _nonce + 1;

      accounts [_from] = balance;
      accounts [_to] = safeAdd (accounts [_to], _value);
      accounts [feeCollector] = safeAdd (accounts [feeCollector], FEE);
      accounts [msg.sender] = safeAdd (accounts [msg.sender], _fee);

      Transfer (_from, _to, _value);
      Transfer (_from, feeCollector, FEE);
      Transfer (_from, msg.sender, _fee);

      return true;
    }
  }

  /**
   * Create tokens.
   *
   * @param _value number of tokens to be created.
   */
  function createTokens (uint256 _value) public returns (bool) {
    require (msg.sender == owner);

    if (_value > 0) {
      if (_value <= safeSub (MAX_TOKENS_COUNT, tokensCount)) {
        accounts [msg.sender] = safeAdd (accounts [msg.sender], _value);
        tokensCount = safeAdd (tokensCount, _value);

        Transfer (address (0), msg.sender, _value);

        return true;
      } else return false;
    } else return true;
  }

  /**
   * Burn tokens.
   *
   * @param _value number of tokens to burn
   */
  function burnTokens (uint256 _value) public returns (bool) {
    require (msg.sender == owner);

    if (_value > 0) {
      if (_value <= accounts [msg.sender]) {
        accounts [msg.sender] = safeSub (accounts [msg.sender], _value);
        tokensCount = safeSub (tokensCount, _value);

        Transfer (msg.sender, address (0), _value);

        return true;
      } else return false;
    } else return true;
  }

  /**
   * Freeze token transfers.
   */
  function freezeTransfers () public {
    require (msg.sender == owner);

    if (!frozen) {
      frozen = true;

      Freeze ();
    }
  }

  /**
   * Unfreeze token transfers.
   */
  function unfreezeTransfers () public {
    require (msg.sender == owner);

    if (frozen) {
      frozen = false;

      Unfreeze ();
    }
  }

  /**
   * Set smart contract owner.
   *
   * @param _newOwner address of the new owner
   */
  function setOwner (address _newOwner) public {
    require (msg.sender == owner);

    owner = _newOwner;
  }

  /**
   * Set fee collector.
   *
   * @param _newFeeCollector address of the new fee collector
   */
  function setFeeCollector (address _newFeeCollector) public {
    require (msg.sender == owner);

    feeCollector = _newFeeCollector;
  }

  /**
   * Get address of this smart contract.
   *
   * @return address of this smart contract
   */
  function thisAddress () internal view returns (address) {
    return this;
  }

  /**
   * Get address of message sender.
   *
   * @return address of this smart contract
   */
  function messageSenderAddress () internal view returns (address) {
    return msg.sender;
  }

  /**
   * Owner of the smart contract.
   */
  address internal owner;

  /**
   * Address where fees are sent to.
   */
  address internal feeCollector;

  /**
   * Number of tokens in circulation.
   */
  uint256 internal tokensCount;

  /**
   * Whether token transfers are currently frozen.
   */
  bool internal frozen;

  /**
   * Mapping from sender's address to the next delegated transfer nonce.
   */
  mapping (address => uint256) internal nonces;

  /**
   * Logged when token transfers were frozen.
   */
  event Freeze ();

  /**
   * Logged when token transfers were unfrozen.
   */
  event Unfreeze ();
}
