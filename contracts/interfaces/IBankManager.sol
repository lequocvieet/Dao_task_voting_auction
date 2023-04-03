// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

interface IBankManager {
    function mint(address tokenAddress, address to, uint amount) external;

    function burn(address tokenAddress, uint amount) external;

    function transfer(
        address tokenAddress,
        address recipient,
        uint amount
    ) external;

    function balanceOf(
        address user,
        address tokenAddress
    ) external returns (uint);
}
