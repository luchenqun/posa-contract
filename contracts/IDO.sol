// contracts/IDO.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";
import "./LKKToken.sol";

// √ 1、预售期设置：设置开始时间和结束时间，开始前、结束后合约不接受交易，可修改结束时间（不能早于当前时间）
// √ 2、暂停预售设置：暂停预售，可开启暂停，可关闭暂停
// √ 3、预售总量设置：即使项目方往预售合约中存入了超过总量设置的LKK，实际预售总量也不会超过该设置
// √ 4、当前剩余待售数量查询：小于单次交易最小购买数量，则不再接收新的交易
// √ 5、单次交易购买最小数量、单次交易最大数量、单个地址的购买数量上限设置：{最大购买数量，当前预售期余量，单个地址购买数量上限-已购买总量}三者中较小值，如果较小值已经低于最小购买数量，则用户无法再继续购买，可查询
// √ 6、当前用户地址已购买的总量查询
// √ 7、支付币种和预售单价设置：不接受设置外的币种支付，可查询，可更新
// √ 8、设置收款地址：接收用户支付的代币，可查询，可修改，可设置多地址和分配比例，每个地址按比例分得入金，至少保留一个收款地址
// √ 9、预售合约Owner的存入（deposit）预售币种的功能：不接收预售币种以外的token存入
// √ 10、预售合约Owner在预售期结束后提取（withdraw）或销毁（burn）合约未售出的剩余数量的功能
// √ 11、变更合约Owner的TransferOwnership功能
// 12、处理预售交易订单，向用户单次交易订单转出10%币种，并记录时间戳，将剩余90%锁仓在预售合约里，解锁封闭期为n天，每张订单在n天后按每次解锁间隔天数m天、按x%比例解锁（最后一次比例小于x%，按实际比例解锁），用户可通过claim方式自行提取已解锁的数量的功能
// 13、用户地址当前可提取（已解锁）数量的查询
// 14、用户地址当前剩余锁仓量的查询
// 15、用户提取已解锁数量的功能，每次提取的数量不可超过当前可提取数量，提取后更新（扣减）可提取数量的值
// 16、用户购买方法中记录订单ID（字节、用于回传查询，可以不传参）及订单ID查询（返回用户地址[可行的话或交易哈希值]），用户解锁提取方法中记录订单ID（字节、用于回传查询，可以不传参）及订单ID查询（返回用户地址[可行的话或交易哈希值]）

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

contract IDO is Ownable {
    // 收款对象结构体
    struct Payee {
        address payable target; // 收款人
        uint32 percentage; // 收款百分比
    }
    struct Balance {
        address target; // 收款人
        uint256 origin; // 原始金额
        uint256 amount; // 金额
        uint256 deblock; // 解锁数量
        uint256 time; // 购买时间
        uint256 currency; // 购买币种
    }

    string name; // 预售名称
    address usdtAddress; // usdt 合约
    address lkkAddress; // lkk 合约
    uint256 presellMax; // 预售总量
    uint256 presellTotal; // 已售总量
    uint256 beginTime; // 预售开始时间
    uint256 endTime; // 预售结束时间
    uint256 perMinBuy; // 每次最低购买
    uint256 perMaxBuy; // 每次最大购买
    uint256 limitBuy; // 最大购买
    uint256 releaseRatio; // 购买释放比例
    uint256 lockTime; // 买了之后，封闭多长时间不允许提取，单位秒
    uint256 deblockTime; // 解锁时间长度，单位秒
    uint256 deblockCount; // 在 deblockTime 可线性解锁多少次
    uint256 oriTokenToLkkRation; // 原生 token 兑换 lkk 比例
    uint256 usdtToLkkRation; // usdt 兑换 lkk比例
    bool pause; // 预售暂停
    Payee[] public payees; // 收款人百分比
    Balance[] public _balances; // 用户购买lkk查询

    fallback() external payable {}

    receive() external payable {}

    // 购买限制
    modifier ensure(uint256 lkkAmount) {
        require(endTime >= block.timestamp, "IDO: EXPIRED"); // 预售时间已结束
        require(beginTime <= block.timestamp, "IDO: TOO EARLY"); // 预售时间未开始
        require(pause == false, "IDO: PAUSEING"); // 暂停购买
        require(
            presellMax - presellTotal > perMinBuy,
            "IDO: The surplus does not meet the word purchase minimum"
        ); // 剩余量已小于单次最低购买
        require(
            presellTotal + lkkAmount <= presellMax,
            "IDO: presellTotal must less than presellMax"
        ); // 不能超过预售数量
        require(
            lkkAmount <= perMaxBuy,
            "IDO: lkkAmount must less than perMaxBuy"
        ); // 单次购买必须小于最大购买
        require(
            lkkAmount >= perMinBuy,
            "IDO: lkkAmount must more than perMinBuy"
        ); // 单次购买最少购买
        _;
    }

    constructor(
        string memory _name,
        uint256 _presellMax,
        address _usdtAddress,
        address _lkkAddress,
        uint256 _beginTime,
        uint256 _endTime,
        uint256 _perMinBuy,
        uint256 _perMaxBuy,
        uint256 _limitBuy // 入参过多会导致栈溢出 // uint256 _releaseRatio // uint256 _lockTime // uint256 _deblockStartTime // uint256 _deblockEndTime // uint256 _deblockCount, // uint256 _oriTokenToLkkRation, // uint256 _usdtToLkkRation
    ) {
        name = _name;
        usdtAddress = _usdtAddress;
        lkkAddress = _lkkAddress;
        presellMax = _presellMax;
        beginTime = _beginTime;
        endTime = _endTime;

        perMinBuy = _perMinBuy;
        perMaxBuy = _perMaxBuy;
        limitBuy = _limitBuy;

        payees.push(Payee(payable(msg.sender), 100)); // 默认部署者全部收了

        releaseRatio = 10;
        lockTime = beginTime + 3 * 30 * 24 * 3600; // 锁三个月
        deblockTime = 3 * 30 * 24 * 3600; // 解锁时间
        deblockCount = 10; // 能解锁10次
        oriTokenToLkkRation = 1024; // 一个原生币能换多少个LKK(注意要考虑小数位数)
        usdtToLkkRation = 8; // 一个原生币能换多少个LKK(注意要考虑小数位数)

        pause = false;
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

    // 传入原生币数量，能换取多少LKK币
    function getLkkByOriToken(uint256 amount) public view returns (uint256) {
        return oriTokenToLkkRation * amount;
    }

    // 传入USDT数量，能换取多少LKK币
    function getLkkByUSDT(uint256 amount) public view returns (uint256) {
        return usdtToLkkRation * amount;
    }

    // 使用原生币购买lkk
    function buyWithOriToken()
        external
        payable
        virtual
        ensure(msg.value * oriTokenToLkkRation)
        returns (bool)
    {
        uint256 value = msg.value;
        uint256 lkkAmount = oriTokenToLkkRation * value;
        uint256 lockLkkAmount = (lkkAmount * (100 - releaseRatio)) / 100;

        // 打lkk给用户
        LKKToken(lkkAddress).transfer(msg.sender, lkkAmount - lockLkkAmount);

        // 收钱
        uint256 curSum = 0;
        for (uint256 i = 0; i < payees.length; i++) {
            uint256 curAmount = (i == payees.length)
                ? (lkkAmount - curSum)
                : ((value * payees[i].percentage) / 100);
            payees[i].target.transfer(curAmount);
            curSum += curAmount;
        }

        presellTotal += lkkAmount;
        _balances.push(
            Balance(
                msg.sender,
                value,
                lkkAmount,
                lkkAmount - lockLkkAmount,
                block.timestamp,
                0
            )
        );
        return true;
    }

    // 使用usdt购买lkk
    function buyWithUSDT(uint256 usdtAmount)
        external
        virtual
        ensure(usdtToLkkRation * usdtAmount)
        returns (bool)
    {
        uint256 lkkAmount = usdtToLkkRation * usdtAmount;
        uint256 lockLkkAmount = (lkkAmount * (100 - releaseRatio)) / 100;

        // 打lkk给用户
        LKKToken(lkkAddress).transfer(msg.sender, lkkAmount - lockLkkAmount);

        console.log("buyWithUSDT:", msg.sender, usdtAmount, lkkAmount);
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

        presellTotal += lkkAmount;
        _balances.push(
            Balance(
                msg.sender,
                usdtAmount,
                lkkAmount,
                lkkAmount - lockLkkAmount,
                block.timestamp,
                1
            )
        );

        return true;
    }

    // 解锁LKK
    function deblockLkk(uint256 amount) external virtual returns (bool) {
        // 打lkk给用户
        uint256 lockAmount = lockBalanceOf(msg.sender); // @todo 此处应该线性计算可解锁的数量
        require(
            lockAmount >= amount,
            "IDO: lockAmount shoud greater than amount"
        );

        uint256 total = 0;
        for (uint256 i = 0; i < _balances.length; i++) {
            uint256 curUndeblock = _balances[i].amount - _balances[i].deblock;
            if (_balances[i].target == msg.sender && curUndeblock > 0) {
                total += curUndeblock;
                if (total <= amount) {
                    _balances[i].deblock = _balances[i].amount;
                } else {
                    _balances[i].deblock =
                        _balances[i].deblock +
                        (total - amount); // 解锁一部分
                    break;
                }
            }
        }
        LKKToken(lkkAddress).transfer(msg.sender, amount);

        return true;
    }

    // 查询用户购买了多少
    function balanceOf(address src) public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < _balances.length; i++) {
            total += _balances[i].target == src ? _balances[i].amount : 0;
        }
        return total;
    }

    // 查询用户还有多少锁仓
    function lockBalanceOf(address src) public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < _balances.length; i++) {
            total += _balances[i].target == src
                ? (_balances[i].amount - _balances[i].deblock)
                : 0;
        }
        return total;
    }

    function updatePresellMax(uint256 _presellMax) public onlyOwner {
        presellMax = _presellMax;
    }

    function updatePresellTotal(uint256 _presellTotal) public onlyOwner {
        presellTotal = _presellTotal;
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

    function updateReleaseRatio(uint256 _releaseRatio) public onlyOwner {
        releaseRatio = _releaseRatio;
    }

    function updateLockTime(uint256 _lockTime) public onlyOwner {
        lockTime = _lockTime;
    }

    function updateDeblockTime(uint256 _deblockTime) public onlyOwner {
        deblockTime = _deblockTime;
    }

    function updateDeblockCount(uint256 _deblockCount) public onlyOwner {
        deblockCount = _deblockCount;
    }

    function updateBeginTime(uint256 _beginTime) public onlyOwner {
        require(
            _beginTime >= block.timestamp,
            "IDO: BeginTime shoud  greater than current time"
        );
        beginTime = _beginTime;
    }

    function updateEndtime(uint256 _endTime) public onlyOwner {
        require(
            _endTime >= block.timestamp,
            "IDO: endTime shoud  greater than current time"
        );
        endTime = _endTime;
    }

    function updatePause(bool _pause) public onlyOwner {
        pause = _pause;
    }

    function updateOriTokenToLkkRation(uint256 _oriTokenToLkkRation)
        public
        onlyOwner
    {
        oriTokenToLkkRation = _oriTokenToLkkRation;
    }

    function updateUsdtToLkkRation(uint256 _usdtToLkkRation) public onlyOwner {
        usdtToLkkRation = _usdtToLkkRation;
    }

    function updatePayees(
        address[] calldata targets,
        uint32[] calldata percentages
    ) public onlyOwner {
        require(
            targets.length == percentages.length,
            "IDO: targets.length should equal percentages.length"
        );

        uint256 total = 0;
        for (uint256 i = 0; i < targets.length; i++) {
            // 防止溢出攻击
            require(
                percentages[i] <= 100,
                "IDO: percentages must less than 100"
            );
            total += percentages[i];
        }
        require(total == 100, "IDO: percentages sum must 100");

        delete payees;
        for (uint256 i = 0; i < targets.length; i++) {
            payees.push(Payee(payable(targets[i]), percentages[i]));
        }
    }
}
