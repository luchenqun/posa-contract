// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ILKKToken {
    function balanceOf(address who) external view returns (uint256);

    // 这个不返回 bool 值，太坑了
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function transfer(address recipient, uint256 amount) external returns (bool);
}
