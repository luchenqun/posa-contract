// contracts/IDO.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

abstract contract TetherERC20 {
    function totalSupply() public view virtual returns (uint256);

    function balanceOf(address who) public view virtual returns (uint256);

    function transfer(address to, uint256 value) public virtual;

    // 这个不返回 bool 值，太坑了
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public virtual;
}

contract PreSell is Ownable {
    enum Currency {
        OriToken,
        USDT,
        Lkk
    }
    // 收款对象结构体
    struct Payee {
        address payable target; // 收款人
        uint32 percentage; // 收款百分比
    }
    struct Balance {
        address target; // 收款人
        uint256 origin; // 原始金额
        uint256 time; // 购买时间
        Currency currency; // 购买币种
    }

    address public usdtAddress; // usdt 合约
    uint256 public presellMax; // 预售总量
    uint256 public presellOriTotal; // 已售总量
    uint256 public presellUsdtTotal; // 已售总量
    uint256 public beginTime; // 预售开始时间
    uint256 public endTime; // 预售结束时间
    uint256 public perMinBuy; // 每次最低购买多少个游戏道具
    uint256 public perMaxBuy; // 每次最大购买多少个游戏道具
    uint256 public limitBuy; // 最多购买多少个游戏道具
    bool public pause; // 预售暂停
    Payee[] public payees; // 收款人百分比
    mapping(address => Balance[]) public balances; // 户购买lkk查询

    fallback() external payable {}

    receive() external payable {}

    // 购买限制
    modifier ensure(uint256 amount) {
        require(endTime >= block.timestamp, "PreSell: EXPIRED"); // 预售时间已结束
        require(beginTime <= block.timestamp, "PreSell: TOO EARLY"); // 预售时间未开始
        require(pause == false, "PreSell: PAUSEING"); // 暂停购买
        require(amount <= perMaxBuy, "PreSell: count must less than perMaxBuy"); // 单次购买必须小于最大购买
        require(amount >= perMinBuy, "PreSell: count must more than perMinBuy"); // 单次购买最少购买
        _;
    }

    constructor(
        address _usdtAddress,
        address[] memory targets, 
        uint32[] memory percentages,
        uint256[] memory params
    ) {
        usdtAddress = _usdtAddress;

        presellMax = params[0];
        beginTime = params[1];
        endTime = params[2];

        perMinBuy = params[3];
        perMaxBuy = params[4];
        limitBuy = params[5];

        pause = false;

        updatePayees(targets, percentages);
    }

    // 使用原生币购买游戏道具
    function buyWithOriToken() external payable virtual ensure(msg.value) returns (bool) {
        // 收钱
        uint256 curSum = 0;
        for (uint256 i = 0; i < payees.length; i++) {
            uint256 curAmount = (i == payees.length) ? (msg.value - curSum) : ((msg.value * payees[i].percentage) / 100);
            payees[i].target.transfer(curAmount);
            curSum += curAmount;
        }

        presellOriTotal += msg.value;
        Balance[] storage _balances = balances[msg.sender];
        _balances.push(Balance(msg.sender, msg.value, block.timestamp, Currency.OriToken));
        return true;
    }

    // 使用usdt购买lkk
    function buyWithUSDT(uint256 usdtAmount) external virtual ensure(usdtAmount) returns (bool) {
        // 收钱
        uint256 curSum = 0;
        for (uint256 i = 0; i < payees.length; i++) {
            uint256 curAmount = (i == payees.length) ? (usdtAmount - curSum) : ((usdtAmount * payees[i].percentage) / 100);
            TetherERC20(usdtAddress).transferFrom(msg.sender, payees[i].target, curAmount);
            curSum += curAmount;
        }
        presellUsdtTotal += usdtAmount;
        Balance[] storage _balances = balances[msg.sender];
        _balances.push(Balance(msg.sender, usdtAmount, block.timestamp, Currency.USDT));
        return true;
    }

    // 查询用户购买了多少
    function balanceOf(address src) public view returns (uint256) {
        uint256 total = 0;
        Balance[] memory _balances = balances[src];
        for (uint256 i = 0; i < _balances.length; i++) {
            total += _balances[i].origin;
        }
        return total;
    }

    function updatePresellMax(uint256 _presellMax) public onlyOwner {
        presellMax = _presellMax;
    }

    function updatePerMinBuy(uint256 _perMinBuy) public onlyOwner {
        perMinBuy = _perMinBuy;
    }

    function updatePerMaxBuy(uint256 _perMaxBuy) public onlyOwner {
        perMaxBuy = _perMaxBuy;
    }

    function updateLimitBuy(uint256 _limitBuy) public onlyOwner {
        limitBuy = _limitBuy;
    }

    function updateBeginTime(uint256 _beginTime) public onlyOwner {
        require(_beginTime >= block.timestamp, "PreSell: BeginTime shoud  greater than current time");
        beginTime = _beginTime;
    }

    function updateEndtime(uint256 _endTime) public onlyOwner {
        require(_endTime >= block.timestamp, "PreSell: endTime shoud  greater than current time");
        endTime = _endTime;
    }

    function updatePause(bool _pause) public onlyOwner {
        pause = _pause;
    }

    function updatePayees(address[] memory targets, uint32[] memory percentages) public onlyOwner {
        require(targets.length == percentages.length, "PreSell: targets.length should equal percentages.length");

        uint256 total = 0;
        for (uint256 i = 0; i < targets.length; i++) {
            // 防止溢出攻击
            require(percentages[i] <= 100, "PreSell: percentages must less than 100");
            total += percentages[i];
        }
        require(total == 100, "PreSell: percentages sum must 100");

        delete payees;
        for (uint256 i = 0; i < targets.length; i++) {
            payees.push(Payee(payable(targets[i]), percentages[i]));
        }
    }
}