// SPDX-License-Identifier: MIT
//BankManager manages all balance of all account
// and contract in many different ERC20 token type
pragma solidity ^0.8.0;

import "./Token.sol";

contract BankManager {
    address private owner;
    mapping(address => mapping(address => uint)) private balances; // mapping of user addresses to token addresses to balances

    event Mint(address indexed account, uint amount);
    event Burn(address indexed account, uint amount);
    event Transfer(address indexed from, address indexed to);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only the contract owner can call this function"
        );
        _;
    }

    function mint(address tokenAddress, uint amount) public onlyOwner {
        Token(tokenAddress).mint(address(this), amount); // Mint new tokens and add them to the contract's balance
        balances[address(this)][tokenAddress] += amount;
    }

    function burn(address tokenAddress, uint amount) public onlyOwner {
        require(
            balances[address(this)][tokenAddress] >= amount,
            "Not enough tokens to burn"
        );
        Token(tokenAddress).burn(address(this), amount); // Burn the specified amount of tokens
        balances[address(this)][tokenAddress] -= amount;
    }

    function transfer(
        address tokenAddress,
        address recipient,
        uint amount
    ) public {
        require(
            balances[msg.sender][tokenAddress] >= amount,
            "Not enough funds to transfer"
        );

        Token(tokenAddress).transfer(recipient, amount); // Transfer tokens to the recipient
        balances[msg.sender][tokenAddress] -= amount;
        balances[recipient][tokenAddress] += amount;
    }

    function balanceOf(
        address user,
        address tokenAddress
    ) public view returns (uint) {
        return balances[user][tokenAddress];
    }
}
