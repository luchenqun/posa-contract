// contracts/IDO.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";
import "./LKKToken.sol";

// 1、预售期设置：设置开始时间和结束时间，开始前、结束后合约不接受交易，可修改结束时间（不能早于当前时间）
// 2、暂停预售设置：暂停预售，可开启暂停，可关闭暂停
// 3、预售总量设置：即使项目方往预售合约中存入了超过总量设置的LKK，实际预售总量也不会超过该设置
// 4、当前剩余待售数量查询：小于单次交易最小购买数量，则不再接收新的交易
// 5、单次交易购买最小数量、单次交易最大数量、单个地址的购买数量上限设置：{最大购买数量，当前预售期余量，单个地址购买数量上限-已购买总量}三者中较小值，如果较小值已经低于最小购买数量，则用户无法再继续购买，可查询
// 6、当前用户地址已购买的总量查询
// 7、支付币种和预售单价设置：不接受设置外的币种支付，可查询，可更新
// 8、设置收款地址：接收用户支付的代币，可查询，可修改，可设置多地址和分配比例，每个地址按比例分得入金，至少保留一个收款地址
// 9、预售合约Owner的存入（deposit）预售币种的功能：不接收预售币种以外的token存入
// 10、预售合约Owner在预售期结束后提取（withdraw）或销毁（burn）合约未售出的剩余数量的功能
// 11、变更合约Owner的TransferOwnership功能
// 12、处理预售交易订单，向用户单次交易订单转出10%币种，并记录时间戳，将剩余90%锁仓在预售合约里，解锁封闭期为n天，每张订单在n天后按每次解锁间隔天数m天、按x%比例解锁（最后一次比例小于x%，按实际比例解锁），用户可通过claim方式自行提取已解锁的数量的功能
// 13、用户地址当前可提取（已解锁）数量的查询
// 14、用户地址当前剩余锁仓量的查询
// 15、用户提取已解锁数量的功能，每次提取的数量不可超过当前可提取数量，提取后更新（扣减）可提取数量的值

abstract contract TetherERC20 {
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
