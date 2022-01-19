// contracts/IDO.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";
import "./interfaces/IBEP20USDT.sol";

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
        address target; // 付款人
        uint256 origin; // 当时金额
        uint256 time; // 购买时间
        Currency currency; // 购买币种
        uint256 toPreSell; // 当时单价
        uint256 orderId; //订单ID
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
    uint256 public oriTokenToPreSell; // 需要多少原生 token 购买一张入场券
    uint256 public usdtToPreSell; // 需要多少原生 usdt 购买一张入场券

    bool public pause; // 预售暂停
    Payee[] public payees; // 收款人百分比
    mapping(address => Balance[]) public balances; // 户购买lkk查询
    mapping(uint256 => address) public buyRecord; //订单ID-用户购买记录

    fallback() external payable {}

    receive() external payable {}

    // 购买限制
    modifier ensure(uint256 exValue, uint256 exRatio) {
        uint256 mod = exValue % exRatio;
        require(mod == 0, "PreSell: not an exact multiple");
        uint256 amount = exValue / exRatio;
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
        oriTokenToPreSell = params[6];
        usdtToPreSell = params[7];

        pause = false;

        updatePayees(targets, percentages);
    }

    // 使用原生币购买
    function buyWithOriToken(uint256 orderId) external payable virtual ensure(msg.value, oriTokenToPreSell) returns (bool) {
        uint256 actual = msg.value;
        console.log("PreSel buyWithOriToken: %d/%d=%d", actual, oriTokenToPreSell, actual / oriTokenToPreSell);
        // 收钱
        uint256 curSum = 0;
        for (uint256 i = 0; i < payees.length; i++) {
            uint256 curAmount = (i == payees.length - 1) ? (actual - curSum) : ((actual * payees[i].percentage) / 100);
            payees[i].target.transfer(curAmount);
            curSum += curAmount;
        }

        presellOriTotal += actual;
        Balance[] storage _balances = balances[msg.sender];
        _balances.push(Balance(msg.sender, actual, block.timestamp, Currency.OriToken, oriTokenToPreSell, orderId));
        buyRecord[orderId] = msg.sender;
        return true;
    }

    // 使用usdt购买
    function buyWithUSDT(uint256 usdtAmount, uint256 orderId) external virtual ensure(usdtAmount, usdtToPreSell) returns (bool) {
        console.log("PreSel buyWithUSDT: %d/%d=%d", usdtAmount, usdtToPreSell, usdtAmount / usdtToPreSell);
        // 收钱
        uint256 curSum = 0;
        for (uint256 i = 0; i < payees.length; i++) {
            uint256 curAmount = (i == payees.length - 1) ? (usdtAmount - curSum) : ((usdtAmount * payees[i].percentage) / 100);
            IBEP20USDT(usdtAddress).transferFrom(msg.sender, payees[i].target, curAmount);
            curSum += curAmount;
        }
        presellUsdtTotal += usdtAmount;
        Balance[] storage _balances = balances[msg.sender];
        _balances.push(Balance(msg.sender, usdtAmount, block.timestamp, Currency.USDT, usdtToPreSell, orderId));
        buyRecord[orderId] = msg.sender;
        return true;
    }

    // 查询用户购买多少张券
    function balanceOf(address src) public view returns (uint256) {
        uint256 total = 0;
        Balance[] memory _balances = balances[src];
        for (uint256 i = 0; i < _balances.length; i++) {
            total += _balances[i].origin / _balances[i].toPreSell;
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

    function updateOriTokenToPreSell(uint256 _oriTokenToPreSell) public onlyOwner {
        oriTokenToPreSell = _oriTokenToPreSell;
    }

    function updateUsdtToPreSell(uint256 _usdtToPreSell) public onlyOwner {
        usdtToPreSell = _usdtToPreSell;
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

    // 用户的订单详情
    function balanceDetail(address src, uint256 i) public view returns (Balance memory) {
        Balance[] memory _balances = balances[src];
        require(_balances.length > i, "PreSell: balances length shoud greater than index");
        return _balances[i];
    }

    // 根据订单ID查询用户的订单详情
    function balanceDetailByOrderId(uint256 orderId) public view returns (Balance memory) {
        Balance memory balance;
        address src = buyRecord[orderId];
        Balance[] memory _balances = balances[src];
        for (uint256 i = 0; i < _balances.length; i++) {
            if (_balances[i].orderId == orderId) {
                balance = _balances[i];
                break;
            }
        }
        return balance;
    }
}
