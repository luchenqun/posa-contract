// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ILKKToken {
    function balanceOf(address who) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function transfer(address recipient, uint256 amount) external returns (bool);
}
