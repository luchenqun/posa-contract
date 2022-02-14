// contracts/IDO.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";
import "./interfaces/ILKKToken.sol";
import "./interfaces/IBEP20USDT.sol";

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
// √ 12、处理预售交易订单，向用户单次交易订单转出10%币种，并记录时间戳，将剩余90%锁仓在预售合约里，解锁封闭期为n天，每张订单在n天后按每次解锁间隔天数m天、按x%比例解锁（最后一次比例小于x%，按实际比例解锁），用户可通过claim方式自行提取已解锁的数量的功能
// √ 13、用户地址当前可提取（已解锁）数量的查询
// √ 14、用户地址当前剩余锁仓量的查询
// √ 15、用户提取已解锁数量的功能，每次提取的数量不可超过当前可提取数量，提取后更新（扣减）可提取数量的值
// 16、用户购买方法中记录订单ID（字节、用于回传查询，可以不传参）及订单ID查询（返回用户地址[可行的话或交易哈希值]），用户解锁提取方法中记录订单ID（字节、用于回传查询，可以不传参）及订单ID查询（返回用户地址[可行的话或交易哈希值]）

// 一些设计
// 1. 购买立即释放比例下单后不随系统的释放比例更新而更新
// 2. 封闭时长与解锁时长解锁次数随系统的更新而更新

contract IDO is Ownable {
    enum Currency {
        OriToken,
        USDT
    }

    // 收款对象结构体
    struct Payee {
        address payable target; // 收款人
        uint32 percentage; // 收款百分比
    }

    // 购买订单
    struct Balance {
        address target; // 收款人(LKK)
        uint256 origin; // 购买LKK金额
        uint256 amount; // 购买LKK总量
        uint256 deblock; // 解锁数量
        uint256 time; // 购买时间
        Currency currency; // 购买币种
        uint256 releaseRatio; // 当时的解锁比例
        uint256 deblockRatio; //解锁比例
        uint256 orderId; //订单ID
        uint256 deblockCount; //线性解锁次数
    }

    // 解锁订单
    struct Deblock {
        address target; // 收款人
        uint256 amount; // 解锁数量
        uint256 time; // 解锁时间
        uint256 orderId; //订单ID
    }

    string public name; // 预售名称
    address public usdtAddress; // usdt 合约
    address public lkkAddress; // lkk 合约
    uint256 public presellMax; // 预售总量
    uint256 public presellTotal; // 已售总量
    uint256 public beginTime; // 预售开始时间
    uint256 public endTime; // 预售结束时间
    uint256 public perMinBuy; // 每次最低购买
    uint256 public perMaxBuy; // 每次最大购买
    uint256 public limitBuy; // 最大购买
    uint256 public releaseRatio; // 购买释放比例
    uint256 public delockRatio; //解锁比例
    uint256 public lockTime; // 买了之后，封闭多长时间不允许提取，单位秒
    //uint256 public deblockTime; // 解锁总时间长度，单位秒
    uint256 public deblockCount; // 在 deblockTime 可线性解锁多少次
    uint256 public perBlockTime; //每次解锁间隔，单位秒

    uint256 public oriTokenToLkkRationNumerator; // 原生 token 兑换 lkk 比例分子
    uint256 public oriTokenToLkkRationDenominator; // 原生 token 兑换 lkk 比例分母
    uint256 public usdtToLkkRationNumerator; // usdt 兑换 lkk比例分子
    uint256 public usdtToLkkRationDenominator; // usdt 兑换 lkk比例分母

    bool public pause; // 预售暂停
    Payee[] public payees; // 收款人百分比
    mapping(address => Balance[]) public balances; // 用户购买lkk订单
    mapping(address => Deblock[]) public deblocks; // 用户购买解锁lkk订单

    mapping(uint256 => address) public buyRecord; //订单ID-用户购买记录
    mapping(uint256 => address) public deblockRecord; //订单ID-用户解锁记录

    fallback() external payable {}

    receive() external payable {}

    // 购买限制
    modifier ensure(uint256 lkkAmount) {
        require(endTime >= block.timestamp, "IDO: EXPIRED"); // 预售时间已结束
        require(beginTime <= block.timestamp, "IDO: TOO EARLY"); // 预售时间未开始
        require(pause == false, "IDO: PAUSEING"); // 暂停购买
        require(presellMax - presellTotal > perMinBuy, "IDO: The surplus does not meet the word purchase minimum"); // 剩余量已小于单次最低购买
        require(presellTotal + lkkAmount <= presellMax, "IDO: presellTotal must less than presellMax"); // 不能超过预售数量
        require(lkkAmount <= perMaxBuy, "IDO: lkkAmount must less than perMaxBuy"); // 单次购买必须小于最大购买
        require(lkkAmount >= perMinBuy, "IDO: lkkAmount must more than perMinBuy"); // 单次购买最少购买
        _;
    }

    constructor(
        string memory _name,
        address _usdtAddress,
        address _lkkAddress,
        address[] memory targets,
        uint32[] memory percentages,
        uint256[] memory params
    ) {
        name = _name;
        usdtAddress = _usdtAddress;
        lkkAddress = _lkkAddress;

        presellMax = params[0];
        beginTime = params[1];
        endTime = params[2];

        perMinBuy = params[3];
        perMaxBuy = params[4];
        limitBuy = params[5];

        releaseRatio = params[6];
        lockTime = params[7];
        // deblockTime = params[8];
        deblockCount = params[8];
        oriTokenToLkkRationNumerator = params[9];
        oriTokenToLkkRationDenominator = params[10];
        usdtToLkkRationNumerator = params[11];
        usdtToLkkRationDenominator = params[12];
        delockRatio = params[13];
        perBlockTime = params[14];

        pause = false;

        updatePayees(targets, percentages);
    }

    // 存lkk到合约里面
    function dposit(address from, uint256 lkkAmount) external virtual returns (bool) {
        console.log("dposit:", from, address(this), lkkAmount);
        ILKKToken(lkkAddress).transferFrom(from, address(this), lkkAmount);
        return true;
    }

    // 从合约里面提取lkk
    function withdraw(uint256 lkkAmount) public onlyOwner returns (bool) {
        console.log("withdraw:", msg.sender, lkkAmount);
        ILKKToken(lkkAddress).transfer(msg.sender, lkkAmount);
        return true;
    }

    // 传入原生币数量，能换取多少LKK币
    function getLkkByOriToken(uint256 amount) public view returns (uint256) {
        return (oriTokenToLkkRationNumerator * amount) / oriTokenToLkkRationDenominator;
    }

    // 传入USDT数量，能换取多少LKK币
    function getLkkByUSDT(uint256 amount) public view returns (uint256) {
        return (usdtToLkkRationNumerator * amount) / usdtToLkkRationDenominator;
    }

    // 使用原生币购买lkk
    function buyWithOriToken(uint256 orderId) external payable virtual ensure((msg.value * oriTokenToLkkRationNumerator) / oriTokenToLkkRationDenominator) returns (bool) {
        uint256 value = msg.value;
        uint256 lkkAmount = (oriTokenToLkkRationNumerator * value) / oriTokenToLkkRationDenominator;
        uint256 releaseAmount = (lkkAmount * releaseRatio) / 100;

        // 打lkk给用户
        ILKKToken(lkkAddress).transfer(msg.sender, releaseAmount);

        // 收钱
        uint256 curSum = 0;
        for (uint256 i = 0; i < payees.length; i++) {
            uint256 curAmount = (i == payees.length - 1) ? (value - curSum) : ((value * payees[i].percentage) / 100);
            payees[i].target.transfer(curAmount);
            curSum += curAmount;
        }

        presellTotal += lkkAmount;
        Balance[] storage _balances = balances[msg.sender];
        _balances.push(Balance(msg.sender, value, lkkAmount, releaseAmount, block.timestamp, Currency.OriToken, releaseRatio, delockRatio,orderId,deblockCount));
        buyRecord[orderId] = msg.sender;
        return true;
    }

    // 使用原生币购买lkk
    function checkBuyWithUSDT(uint256 usdtAmount) public view returns (string memory) {
        uint256 lkkAmount = (usdtToLkkRationNumerator * usdtAmount) / usdtToLkkRationDenominator;
        if (endTime < block.timestamp) return ("IDO: EXPIRED"); // 预售时间已结束
        if (beginTime > block.timestamp) return ("IDO: TOO EARLY"); // 预售时间未开始
        if (pause == true) return ("IDO: PAUSEING"); // 暂停购买
        if (presellMax - presellTotal <= perMinBuy) return ("IDO: The surplus does not meet the word purchase minimum"); // 剩余量已小于单次最低购买
        if (presellTotal + lkkAmount > presellMax) return ("IDO: presellTotal must less than presellMax"); // 不能超过预售数量
        if (lkkAmount > perMaxBuy) return ("IDO: lkkAmount must less than perMaxBuy"); // 单次购买必须小于最大购买
        if (lkkAmount < perMinBuy) return ("IDO: lkkAmount must more than perMinBuy"); // 单次购买最少购买

        uint256 allowanceUsdtAmount = IBEP20USDT(usdtAddress).allowance(msg.sender, address(this));
        console.log("allowanceUsdtAmount = ", allowanceUsdtAmount);
        if (usdtAmount > allowanceUsdtAmount) return ("IDO: User allowance ido to transferFrom usdt not enough"); // 用户授权额度不够

        uint256 userUsdtAmount = IBEP20USDT(usdtAddress).balanceOf(msg.sender);
        console.log("userUsdtAmount = ", userUsdtAmount);
        if (usdtAmount > userUsdtAmount) return ("IDO: User usdt is not enough"); // 用户usdt够不够

        return "success";
    }

    // 使用usdt购买lkk
    function buyWithUSDT(uint256 usdtAmount, uint256 orderId) external virtual ensure((usdtToLkkRationNumerator * usdtAmount) / usdtToLkkRationDenominator) returns (bool) {
        uint256 lkkAmount = (usdtToLkkRationNumerator * usdtAmount) / usdtToLkkRationDenominator;
        uint256 releaseAmount = (lkkAmount * releaseRatio) / 100;

        // 打lkk给用户
        ILKKToken(lkkAddress).transfer(msg.sender, releaseAmount);

        console.log("buyWithUSDT:", msg.sender, usdtAmount, lkkAmount);
        // 收钱
        uint256 curSum = 0;
        for (uint256 i = 0; i < payees.length; i++) {
            uint256 curAmount = (i == payees.length - 1) ? (usdtAmount - curSum) : ((usdtAmount * payees[i].percentage) / 100);
            IBEP20USDT(usdtAddress).transferFrom(msg.sender, payees[i].target, curAmount);
            curSum += curAmount;
        }

        presellTotal += lkkAmount;
        Balance[] storage _balances = balances[msg.sender];
        _balances.push(Balance(msg.sender, usdtAmount, lkkAmount, releaseAmount, block.timestamp, Currency.USDT, releaseRatio, delockRatio,orderId,deblockCount));
        buyRecord[orderId] = msg.sender;
        return true;
    }

    // 解锁LKK，用户操作从合约提取LKK到自己地址
    function deblockLkk(uint256 amount, uint256 orderId) external virtual returns (bool) {
        uint256 canDeblockAmount = canDeblockBalanceOf(msg.sender);
        require(canDeblockAmount >= amount, "IDO: canDeblockAmount shoud greater than amount");
        require(amount > 0, "IDO: amount shoud greater than 0");

        uint256 total = 0;
        Balance[] storage _balances = balances[msg.sender];
        for (uint256 i = 0; i < _balances.length; i++) {
            Balance memory balance = _balances[i];
            // uint256 curDeblock = canDeblockItemBalance(balance);
            uint256 curDeblock = canDeblockItemBalanceByDelockRatio(balance);
            if (curDeblock > 0) {
                total += curDeblock;
                if (total <= amount) {
                    _balances[i].deblock = _balances[i].deblock + curDeblock;
                } else {
                    _balances[i].deblock = _balances[i].deblock + (total - amount); // 解锁一部分
                    break;
                }
            }
        }

        ILKKToken(lkkAddress).transfer(msg.sender, amount); // 打lkk给用户

        // 记录解锁信息
        Deblock[] storage _deblocks = deblocks[msg.sender];
        _deblocks.push(Deblock(msg.sender, amount, block.timestamp, orderId));
        deblockRecord[orderId] = msg.sender;

        return true;
    }

    // 查询用户购买了多少
    function balanceOf(address src) public view returns (uint256) {
        uint256 total = 0;
        Balance[] storage _balances = balances[src];
        for (uint256 i = 0; i < _balances.length; i++) {
            total += _balances[i].amount;
        }
        return total;
    }

    // 查询用户还有多少锁仓
    function lockBalanceOf(address src) public view returns (uint256) {
        uint256 total = 0;
        Balance[] storage _balances = balances[src];
        for (uint256 i = 0; i < _balances.length; i++) {
            total += (_balances[i].amount - _balances[i].deblock);
        }
        return total;
    }

    // 查询用户已经解锁提取了多少
    function deblockBalanceOf(address src) public view returns (uint256) {
        uint256 total = 0;
        Balance[] storage _balances = balances[src];
        for (uint256 i = 0; i < _balances.length; i++) {
            total += _balances[i].deblock;
        }
        return total;
    }

    // 地址可解锁LKK总数量，可以提取LKK总量
    function canDeblockBalanceOf(address src) public view returns (uint256) {
        uint256 total = 0;
        Balance[] memory _balances = balances[src];
        for (uint256 i = 0; i < _balances.length; i++) {
            Balance memory balance = _balances[i];
            total += canDeblockItemBalance(balance);
        }
        return total;
    }

    // 单条(用户单个订单)可解锁LKK数量
    function canDeblockItemBalance(Balance memory balance) public view returns (uint256) {
        uint256 amount = 0;
        uint256 gapTotal = block.timestamp > (balance.time + lockTime) ? block.timestamp - (balance.time + lockTime) : 0;
        if (gapTotal > 0) {
            // uint256 gapPer = deblockTime / deblockCount; //解锁间隔
            uint256 curDeblockCount = gapTotal / perBlockTime + 1; 
            if (curDeblockCount > deblockCount) {
                curDeblockCount = deblockCount;
            }

            if (curDeblockCount == deblockCount) {
                amount = (balance.amount - balance.deblock); // 此时剩下的全能解锁
            } else {
                uint256 releaseAmount = (balance.amount * balance.releaseRatio) / 100; // 当时买了时候立马释放金额，为什么不用目前的 releaseRatio 呢？因为管理员可能会更改这个值
                uint256 deblockAmount = releaseAmount + ((balance.amount - releaseAmount) / deblockCount) * curDeblockCount; // 总共到现在能解锁多少
                // 有可能因为更新锁定期解锁时长参数，导致已经解锁的比目前算出来能解锁的还要多
                if (deblockAmount > balance.deblock) {
                    amount = (deblockAmount - balance.deblock);
                }
            }
        }
        return amount;
    }

    //按该订单解冻可提取数量
    function canDeblockBalanceByDelockRatio(uint256 orderId) public view returns (uint256){
        Balance memory balance;
        address src = buyRecord[orderId];
        Balance[] memory _balances = balances[src];
        for (uint256 i = 0; i < _balances.length; i++) {
            if (_balances[i].orderId == orderId) {
                balance = _balances[i];
                break;
            }
        }
        return canDeblockItemBalanceByDelockRatio(balance);
    }

    //查询该地址下所有订单已解锁可提取数量（按百分比解锁方式）
    function canDeblockBalanceByAddr(address src) public view returns (uint256){
        uint256 total = 0;
        Balance[] memory _balances = balances[src];
        for (uint256 i = 0; i < _balances.length; i++) {
            Balance memory balance = _balances[i];
            total += canDeblockItemBalanceByDelockRatio(balance);
        }
        return total;
    }

    //查询该地址下单个订单可解锁可提取数量（按百分比解锁方式）
    function canDeblockItemBalanceByDelockRatio(Balance memory balance) public view returns (uint256) {
        uint256 amount = 0;
        uint256 gapTotal = block.timestamp > (balance.time + lockTime) ? block.timestamp - (balance.time + lockTime) : 0;
            if (gapTotal > 0) {

                uint256 curDeblockCount = gapTotal / perBlockTime + 1; 
                if (curDeblockCount > balance.deblockCount) {
                    curDeblockCount = balance.deblockCount;
                }

                if (curDeblockCount == balance.deblockCount) {
                    amount = (balance.amount - balance.deblock); // 此时剩下的全能解锁
                } else {
                    uint256 releaseAmount = (balance.amount * balance.releaseRatio) / 100; // 当时买了时候立马释放金额，为什么不用目前的 releaseRatio 呢？因为管理员可能会更改这个值
                    uint256 deblockAmount = releaseAmount + ((balance.amount * balance.deblockRatio) /100) * curDeblockCount; // 总共到现在能解锁多少
                    // 有可能因为更新锁定期解锁时长参数，导致已经解锁的比目前算出来能解锁的还要多
                    if (deblockAmount > balance.deblock) {
                        amount = (deblockAmount - balance.deblock);
                    }
                }
        }
        return amount;
    }

    // 用户的订单数目
    function balanceLength(address src) public view returns (uint256) {
        Balance[] memory _balances = balances[src];
        return _balances.length;
    }

    // 用户的订单详情
    function balanceDetail(address src, uint256 i) public view returns (Balance memory) {
        Balance[] memory _balances = balances[src];
        require(_balances.length > i, "IDO: balances length shoud greater than index");
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

    // 用户的解锁订单详情
    function deblockDetail(address src, uint256 i) public view returns (Deblock memory) {
        Deblock[] memory _deblocks = deblocks[src];
        require(_deblocks.length > i, "IDO: _deblocks length shoud greater than index"); // 最多1s能解锁一次
        return _deblocks[i];
    }

    // 根据解锁ID查询用户的解锁详情
    function deblockDetailByOrderId(uint256 orderId) public view returns (Deblock memory) {
        Deblock memory deblock;
        address src = deblockRecord[orderId];
        Deblock[] memory _deblocks = deblocks[src];
        for (uint256 i = 0; i < _deblocks.length; i++) {
            if (_deblocks[i].orderId == orderId) {
                deblock = _deblocks[i];
                break;
            }
        }
        return deblock;
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

    function updateDelockRatio(uint256 _delockRatio) public onlyOwner {
        delockRatio = _delockRatio;
    }

    function updateLockTime(uint256 _lockTime) public onlyOwner {
        lockTime = _lockTime;
    }

    // function updateDeblockTime(uint256 _deblockTime) public onlyOwner {
    //     require(_deblockTime > deblockCount, "IDO: deblockTime shoud greater than deblockCount"); // 最多1s能解锁一次
    //     deblockTime = _deblockTime;
    // }

    function updatePerBlockTime(uint256 _perBlockTime) public onlyOwner {
        require(_perBlockTime > deblockCount, "IDO: perBlockTime shoud greater than perBlockTime"); // 最多1s能解锁一次
        perBlockTime = _perBlockTime;
    }

    function updateDeblockCount(uint256 _deblockCount) public onlyOwner {
        require(_deblockCount > 0, "IDO: deblockCount shoud greater than 0");
        deblockCount = _deblockCount;
    }

    function updateBeginTime(uint256 _beginTime) public onlyOwner {
        require(_beginTime >= block.timestamp, "IDO: BeginTime shoud  greater than current time");
        beginTime = _beginTime;
    }

    function updateEndtime(uint256 _endTime) public onlyOwner {
        require(_endTime >= block.timestamp, "IDO: endTime shoud  greater than current time");
        endTime = _endTime;
    }

    function updatePause(bool _pause) public onlyOwner {
        pause = _pause;
    }

    function updateOriTokenToLkkRation(uint256 _oriTokenToLkkRationNumerator, uint256 _oriTokenToLkkRationDenominator) public onlyOwner {
        require(_oriTokenToLkkRationDenominator != 0, "IDO: _oriTokenToLkkRationDenominator shoud not equal 0");
        oriTokenToLkkRationNumerator = _oriTokenToLkkRationNumerator;
        oriTokenToLkkRationDenominator = _oriTokenToLkkRationDenominator;
    }

    function updateUsdtToLkkRation(uint256 _usdtToLkkRationNumerator, uint256 _usdtToLkkRationDenominator) public onlyOwner {
        require(_usdtToLkkRationDenominator != 0, "IDO: _usdtToLkkRationDenominator shoud not equal 0");
        usdtToLkkRationNumerator = _usdtToLkkRationNumerator;
        usdtToLkkRationDenominator = _usdtToLkkRationDenominator;
    }

    function updatePayees(address[] memory targets, uint32[] memory percentages) public onlyOwner {
        require(targets.length == percentages.length, "IDO: targets.length should equal percentages.length");

        uint256 total = 0;
        for (uint256 i = 0; i < targets.length; i++) {
            // 防止溢出攻击
            require(percentages[i] <= 100, "IDO: percentages must less than 100");
            total += percentages[i];
        }
        require(total == 100, "IDO: percentages sum must 100");

        delete payees;
        for (uint256 i = 0; i < targets.length; i++) {
            payees.push(Payee(payable(targets[i]), percentages[i]));
        }
    }
}
