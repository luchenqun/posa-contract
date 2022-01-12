// contracts/IDO.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";
import "./interfaces/ITetherERC20.sol";

// 1、道具预售期设置：设置开始时间和结束时间，开始前、结束后合约不接受交易，可修改结束时间（不能早于当前时间）
// 2、道具暂停预售设置：暂停预售，可开启暂停，可关闭暂停
// 3、道具预售总量设置：累积已销售的数量不可大于道具预售总量设定，当前交易如果会导致累积已销售的数量大于设定，则拒绝交易，可以修改更新设定
// 4、当前剩余待售数量查询：小于单次交易最小购买数量，则不再接收新的交易
// 5、单次交易购买最小数量、单次交易最大数量、单个地址的购买数量上限设置：{最大购买数量，当前预售期余量，单个地址购买数量上限-已购买总量}三者中较小值，如果较小值已经低于最小购买数量，则用户无法再继续购买，可查询
// 6、当前用户地址已购买的总量查询
// 7、支付币种和预售单价设置：不接受设置外的币种支付，可查询，可更新
// 8、设置收款地址：接收用户支付的代币，可查询，可修改，可设置多地址和分配比例，每个地址按比例分得入金，至少保留一个收款地址
// 9、变更合约Owner的TransferOwnership功能
// 10、用户购买方法中记录订单ID（字节、用于回传查询，可以不传参）及订单ID查询（返回用户地址[可行的话或交易哈希值]）
abstract contract GameItem721 {
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external virtual;
}

contract GameItemSell is Ownable {
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
        uint256 count; // 购买个数
        uint256 time; // 购买时间
        Currency currency; // 购买币种
    }

    address public usdtAddress; // usdt 合约
    address public lkkAddress; // lkk 合约
    address public gameItemAddress; // 游戏道具(ERC721)合约
    address public gameItemSupply; // 游戏道具供应方
    uint256 public presellMax; // 预售总量
    uint256 public presellTotal; // 已售总量
    uint256 public beginTime; // 预售开始时间
    uint256 public endTime; // 预售结束时间
    uint256 public perMinBuy; // 每次最低购买多少个游戏道具
    uint256 public perMaxBuy; // 每次最大购买多少个游戏道具
    uint256 public limitBuy; // 最多购买多少个游戏道具

    uint256 public oriTokenToGameItem; // 需要多少原生 token 购买一个道具
    uint256 public usdtToGameItem; // 需要多少原生 usdt 购买一个道具
    uint256 public lkkToGameItem; // 需要多少原生 LKK 购买一个道具

    bool public pause; // 预售暂停
    Payee[] public payees; // 收款人百分比
    mapping(address => Balance[]) public balances; // 户购买lkk查询

    fallback() external payable {}

    receive() external payable {}

    // 购买限制
    modifier ensure(uint256 count) {
        require(endTime >= block.timestamp, "GameItemSell: EXPIRED"); // 预售时间已结束
        require(beginTime <= block.timestamp, "GameItemSell: TOO EARLY"); // 预售时间未开始
        require(pause == false, "GameItemSell: PAUSEING"); // 暂停购买
        require(presellMax - presellTotal > perMinBuy, "GameItemSell: The surplus does not meet the word purchase minimum"); // 剩余量已小于单次最低购买
        require(presellTotal + count <= presellMax, "GameItemSell: presellTotal must less than presellMax"); // 不能超过预售数量
        require(count <= perMaxBuy, "GameItemSell: count must less than perMaxBuy"); // 单次购买必须小于最大购买
        require(count >= perMinBuy, "GameItemSell: count must more than perMinBuy"); // 单次购买最少购买
        _;
    }

    constructor(
        address _usdtAddress,
        address _lkkAddress,
        address _gameItemAddress,
        address _gameItemSupply,
        uint256[] memory params
    ) {
        usdtAddress = _usdtAddress;
        lkkAddress = _lkkAddress;
        gameItemAddress = _gameItemAddress;
        gameItemSupply = _gameItemSupply;

        presellMax = params[0];
        beginTime = params[1];
        endTime = params[2];

        perMinBuy = params[3];
        perMaxBuy = params[4];
        limitBuy = params[5];

        payees.push(Payee(payable(msg.sender), 100)); // 默认部署者全部收了

        oriTokenToGameItem = params[6];
        usdtToGameItem = params[7];
        lkkToGameItem = params[8];

        pause = false;
    }

    // 传入原生币数量，能换取多少个游戏道具
    function getGameItemByOriToken(uint256 amount) public view returns (uint256) {
        return amount / oriTokenToGameItem;
    }

    // 传入USDT数量，能换取多少个游戏道具
    function getGameItemByUSDT(uint256 amount) public view returns (uint256) {
        return amount / usdtToGameItem;
    }

    // 传入LKK数量，能换取多少个游戏道具
    function getGameItemByLkk(uint256 amount) public view returns (uint256) {
        return amount / lkkToGameItem;
    }

    // 使用原生币购买游戏道具
    function buyWithOriToken() external payable virtual ensure(msg.value / oriTokenToGameItem) returns (bool) {
        uint256 count = msg.value / oriTokenToGameItem;
        uint256 actual = count * oriTokenToGameItem; // 只扣实际购买用完的

        // 将游戏道具给到用户
        uint256 index = 0;
        while (index < count) {
            GameItem721(gameItemAddress).transferFrom(gameItemSupply, msg.sender, presellTotal + index);
            index++;
        }

        // 收钱
        uint256 curSum = 0;
        for (uint256 i = 0; i < payees.length; i++) {
            uint256 curAmount = (i == payees.length) ? (actual - curSum) : ((actual * payees[i].percentage) / 100);
            payees[i].target.transfer(curAmount);
            curSum += curAmount;
        }

        presellTotal += count;
        Balance[] storage _balances = balances[msg.sender];
        _balances.push(Balance(msg.sender, actual, count, block.timestamp, Currency.OriToken));
        return true;
    }

    // 使用usdt购买lkk
    function buyWithUSDT(uint256 usdtAmount) external virtual ensure(usdtAmount / usdtToGameItem) returns (bool) {
        uint256 count = usdtAmount / usdtToGameItem;
        uint256 actual = count * usdtToGameItem; // 只扣实际购买用完的

        // 将游戏道具给到用户
        uint256 index = 0;
        while (index < count) {
            GameItem721(gameItemAddress).transferFrom(gameItemSupply, msg.sender, presellTotal + index);
            index++;
        }

        // 收钱
        uint256 curSum = 0;
        for (uint256 i = 0; i < payees.length; i++) {
            uint256 curAmount = (i == payees.length) ? (actual - curSum) : ((actual * payees[i].percentage) / 100);
            ITetherERC20(usdtAddress).transferFrom(msg.sender, payees[i].target, curAmount);
            curSum += curAmount;
        }

        presellTotal += count;
        Balance[] storage _balances = balances[msg.sender];
        _balances.push(Balance(msg.sender, actual, count, block.timestamp, Currency.USDT));
        return true;
    }

    // 使用usdt购买lkk
    function buyWithLkk(uint256 lkkAmount) external virtual ensure(lkkAmount / lkkToGameItem) returns (bool) {
        uint256 count = lkkAmount / lkkToGameItem;
        uint256 actual = count * lkkToGameItem; // 只扣实际购买用完的

        // 将游戏道具给到用户
        uint256 index = 0;
        while (index < count) {
            GameItem721(gameItemAddress).transferFrom(gameItemSupply, msg.sender, presellTotal + index);
            index++;
        }

        // 收钱
        uint256 curSum = 0;
        for (uint256 i = 0; i < payees.length; i++) {
            uint256 curAmount = (i == payees.length) ? (actual - curSum) : ((actual * payees[i].percentage) / 100);
            ITetherERC20(lkkAddress).transferFrom(msg.sender, payees[i].target, curAmount);
            curSum += curAmount;
        }

        presellTotal += count;
        Balance[] storage _balances = balances[msg.sender];
        _balances.push(Balance(msg.sender, actual, count, block.timestamp, Currency.Lkk));
        return true;
    }

    // 查询用户购买了多少
    function balanceOf(address src) public view returns (uint256) {
        uint256 total = 0;
        Balance[] memory _balances = balances[src];
        for (uint256 i = 0; i < _balances.length; i++) {
            total += _balances[i].count;
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

    function updateBeginTime(uint256 _beginTime) public onlyOwner {
        require(_beginTime >= block.timestamp, "GameItemSell: BeginTime shoud  greater than current time");
        beginTime = _beginTime;
    }

    function updateEndtime(uint256 _endTime) public onlyOwner {
        require(_endTime >= block.timestamp, "GameItemSell: endTime shoud  greater than current time");
        endTime = _endTime;
    }

    function updatePause(bool _pause) public onlyOwner {
        pause = _pause;
    }

    function updateOriTokenToGameItem(uint256 _oriTokenToGameItem) public onlyOwner {
        oriTokenToGameItem = _oriTokenToGameItem;
    }

    function updateUsdtToGameItem(uint256 _usdtToGameItem) public onlyOwner {
        usdtToGameItem = _usdtToGameItem;
    }

    function updateLkkToGameItem(uint256 _lkkToGameItem) public onlyOwner {
        lkkToGameItem = _lkkToGameItem;
    }

    function updatePayees(address[] calldata targets, uint32[] calldata percentages) public onlyOwner {
        require(targets.length == percentages.length, "GameItemSell: targets.length should equal percentages.length");

        uint256 total = 0;
        for (uint256 i = 0; i < targets.length; i++) {
            // 防止溢出攻击
            require(percentages[i] <= 100, "GameItemSell: percentages must less than 100");
            total += percentages[i];
        }
        require(total == 100, "GameItemSell: percentages sum must 100");

        delete payees;
        for (uint256 i = 0; i < targets.length; i++) {
            payees.push(Payee(payable(targets[i]), percentages[i]));
        }
    }
}
