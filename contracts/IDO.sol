// contracts/IDO.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";
import "./LKKToken.sol";

abstract contract TetherERC20 {
    // function totalSupply() public view virtual returns (uint256);

    // function decimals() public view virtual returns (uint256);

    // function balanceOf(address who) public view virtual returns (uint256);

    // function transfer(address to, uint256 value) public virtual returns (bool);

    // function transferFrom(
    //     address from,
    //     address to,
    //     uint256 value
    // ) public virtual returns (bool);

    // event Transfer(address indexed from, address indexed to, uint256 value);

    function totalSupply() public view virtual returns (uint256);

    function balanceOf(address who) public view virtual returns (uint256);

    function transfer(address to, uint256 value) public virtual;

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public virtual;
}

contract IDO is Ownable {
    // 收款对象结构体
    struct Payee {
        address payable target; // 收款人
        uint32 percentage; // 收款百分比
    }
    string name; // 预售名称
    address usdtAddress; // usdt 合约
    address lkkAddress; // lkk 合约
    uint256 presellMax; // 预售总量
    uint256 beginTime; // 预售开始时间
    uint256 endTime; // 预售结束时间
    uint256 perMinBuy; // 每次最低购买
    uint256 perMaxBuy; // 每次最大购买
    uint256 limitBuy; // 最大购买
    uint256 releaseRatio; // 购买释放比例
    uint256 closeTime; // 封闭时间，单位秒
    uint256 deblockTime; // 解锁时间，单位秒
    uint256 oriTokenToLkkRation; // 原生 token 兑换 lkk 比例
    uint256 usdtToLkkRation; // usdt 兑换 lkk比例
    Payee[] public payees; // 收款人百分比

    function normalThing() public {
        // anyone can call this normalThing()
    }

    fallback() external payable {}

    receive() external payable {}

    constructor(
        string memory _name,
        uint256 _presellMax,
        address _usdtAddress,
        address _lkkAddress
    ) {
        name = _name;
        usdtAddress = _usdtAddress;
        lkkAddress = _lkkAddress;
        presellMax = _presellMax;
        beginTime = block.timestamp;
        endTime = beginTime + 180 days;

        uint256 d = LKKToken(lkkAddress).decimals();
        perMinBuy = 10 * 10**uint256(d);
        perMaxBuy = 1000 * 10**uint256(d);
        limitBuy = 100000 * 10**uint256(d);

        payees.push(Payee(payable(msg.sender), 100)); // 默认部署者全部收了

        releaseRatio = 10;
        closeTime = 3 * 30 days;
        deblockTime = 3 * 30 days;

        oriTokenToLkkRation = 1024; // 1原生token可以换1024 LKK
        usdtToLkkRation = 8; // 1 usdt可以换8 LKK
    }

    // 存lkk到合约里面
    function dposit(address from, uint256 lkkAmount)
        external
        virtual
        returns (bool)
    {
        console.log("dposit:", from, address(this), lkkAmount);
        LKKToken(lkkAddress).transferFrom(from, address(this), lkkAmount);
        return true;
    }

    // 从合约里面提取lkk
    function withdraw(uint256 lkkAmount) public onlyOwner returns (bool) {
        console.log("withdraw:", msg.sender, lkkAmount);
        LKKToken(lkkAddress).transfer(msg.sender, lkkAmount);
        return true;
    }

    // 使用原生币购买lkk
    function buyWithOriToken() external payable virtual returns (bool) {
        uint256 value = msg.value;
        uint256 lkkAmount = oriTokenToLkkRation * value;
        // 打lkk给用户
        LKKToken(lkkAddress).transfer(msg.sender, lkkAmount);

        // 收钱
        uint256 curSum = 0;
        for (uint256 i = 0; i < payees.length; i++) {
            uint256 curAmount = (i == payees.length)
                ? (lkkAmount - curSum)
                : ((value * payees[i].percentage) / 100);
            payees[i].target.transfer(curAmount);
            curSum += curAmount;
        }

        return true;
    }

    // 使用usdt购买lkk
    function buyWithUSDT(uint256 usdtAmount) external virtual returns (bool) {
        uint256 lkkAmount = usdtToLkkRation * usdtAmount;
        // 打lkk给用户
        LKKToken(lkkAddress).transfer(msg.sender, lkkAmount);
        // 收钱
        uint256 curSum = 0;
        for (uint256 i = 0; i < payees.length; i++) {
            uint256 curAmount = (i == payees.length)
                ? (usdtAmount - curSum)
                : ((usdtAmount * payees[i].percentage) / 100);
            TetherERC20(usdtAddress).transferFrom(
                msg.sender,
                payees[i].target,
                curAmount
            );
            curSum += curAmount;
        }
        return true;
    }

    function updateEndtime(uint256 _endTime) public onlyOwner {
        endTime = _endTime;
    }
}
