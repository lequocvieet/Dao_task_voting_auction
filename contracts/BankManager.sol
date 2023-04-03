// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Token.sol";
import "./interfaces/IBankManager.sol";

//BankManager manages balance of all account and contract in many different ERC20 type
contract BankManager is IBankManager {
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

    // Mint new tokens
    function mint(
        address tokenAddress,
        address to,
        uint amount
    ) public onlyOwner {
        Token(tokenAddress).mint(to, amount);
        balances[to][tokenAddress] += amount;
    }

    // Burn the specified amount of tokens
    function burn(address tokenAddress, uint amount) public onlyOwner {
        require(
            balances[address(this)][tokenAddress] >= amount,
            "Not enough tokens to burn"
        );
        Token(tokenAddress).burn(address(this), amount);
        balances[address(this)][tokenAddress] -= amount;
    }

    function transfer(
        address from,
        address tokenAddress,
        address recipient,
        uint amount
    ) public {
        console.log("msg balance", balances[from][tokenAddress]);
        require(
            balances[from][tokenAddress] >= amount,
            "Not enough funds to transfer"
        );
        // Transfer tokens to the recipient
        Token(tokenAddress).transfer(recipient, amount);
        balances[from][tokenAddress] -= amount;
        balances[recipient][tokenAddress] += amount;
    }

    function balanceOf(
        address user,
        address tokenAddress
    ) public view returns (uint) {
        return balances[user][tokenAddress];
    }
}
