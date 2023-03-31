// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

interface IBankManager {
    function mint(address tokenAddress, uint256 amount) external;

    function burn(address tokenAddress, uint256 amount) external;

    function transfer(
        address tokenAddress,
        address recipient,
        uint256 amount
    ) external;

    function balanceOf(address user, address tokenAddress) external;
}
