// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// 零钱机销售
// 海外链商零钱机销售新增产品需求：
// 1.合约实现零钱机销售额实时分账；
// 分账说明：
// 分账角色：
// 3月30日前分配比例：
// 1.特许经销商                  20%
// 2.预留出金                    20%
// 3.公司内部市场人员             20%
// 4.平台账户                    40%

// 特许经销商挂靠在公司内部市场人员下；
// 举例：
// 公司内部市场员工A，发展推广了特许经销商A1/特许经销商A2/特许经销商A3;
// A1/A2/A3挂靠在员工A下；A1/A2/A3零钱机销售额分配如下：
// 分账角色：
// 3月30日前分配比例：
// 1.特许经销商——A1/A2/A3             20%
// 2.预留出金                         20%
// 3.公司内部市场人员——A               20%
// 4.平台账户                         40%

// 特别说明：
// a.如果特许经销商未挂靠到公司内部市场人员下面，则第三项20%不分配，直接进入平台账户；
// b.分配会根据销售情况进行调整，因此，需设置为可配置；
// c.目前支付方式是波场usdt，因为结算也是波场usdt；
contract ChangerMachine is Ownable {

    address public usdtAddress; // usdt 合约

    Payee public reserve; // 预留
    Payee public platform; // 平台
    Payee[] public distributors; // 经销商
    Payee[] public persons; // 市场人员

    Distributor[] public distributorInfo; // 所有经销商信息
    Order[] public orders; // 所有订单

    mapping(address => Distributor[]) affiliated; // 市场人员名下的经销商
    mapping(uint256 => Share) shares; // 订单分成

    // 经销商结构体
    struct Distributor {
        address payable beneficiary; // 收款地址
        address payable personAddress; // 挂靠内部市场人员地址
    }

    // 收款比例结构体
    struct Payee {
        address payable beneficiary; // 收款人
        uint16 percentage; // 收款百分比
    }

    // 订单结构体
    struct Order {
        uint256 orderId; // 订单id
        address payable distributor; // 经销商
        address payable buyer; // 购买人
        uint256 amount; // 金额
    }

    // 订单分成结构体
    struct Share {
        uint256 orderId; // 订单id
        uint256 amount; // 分成金额
        address payable reserveAddress; // 预留地址
        uint16 reserve; // 当前订单预留分成比例
        address payable platformAddress; // 平台地址
        uint16 platform; // 当前订单平台比例
        address payable distributorAddress; // 经销商地址
        uint16 distributor; // 当前订单经销商比例
        address payable personAddress; // 市场人员地址
        uint16 person; // 当前订单市场人员比例
    }

    
    // 事件
    event splitAccountEevent(uint256 _orderId, uint256 _amount, address payable _distributorAddress, Share share);


    /**
     * 构造函数：初始化usdt地址、预留出金和平台账户及分配比例
     */
    constructor(address _usdtAddress, address[] memory _beneficiaries, uint16[] memory _percentages) {
        usdtAddress = _usdtAddress;
        reserve = Payee(payable(_beneficiaries[0]), _percentages[0]);
        platform = Payee(payable(_beneficiaries[1]), _percentages[1]);
    }

    /**
     * 设置预留出金地址和比例
     */
    function setReservePayee(address payable _beneficiaries, uint16 _percentages) public onlyOwner {
        require(_percentages>0 && _percentages<100, "percent set error!");
        reserve = Payee(payable(_beneficiaries), _percentages);
    }

    /**
     * 设置平台地址和比例
     */
    function setPlatformPayee(address payable _beneficiaries, uint16 _percentages) public onlyOwner {
        require(_percentages>0 && _percentages<100, "percent set error!");
        platform = Payee(payable(_beneficiaries), _percentages);
    }


    /**
     * 获取市场人员和经销商间的关系
     */
    function getAffiliatedDetail(address payable _personAddress) public view returns(Distributor[] memory) {
        return affiliated[_personAddress];
    }

    /**
     * 获取某笔订单分成信息
     */
    function getShareDetail(uint256 _orderId) public view returns(Share memory) {
        return shares[_orderId];
    }

    /**
     * 获取经销商列表
     */
    function getAllDistributor() public view returns(Distributor[] memory) {
        return distributorInfo;
    }


    /**
     * 添加市场人员地址和比例
     */
    function addPersonsPayee(address payable _beneficiaries, uint16 _percentages) public onlyOwner {
        require(!checkPersonAddress(_beneficiaries), "person address has exist!");
        require(_percentages>0 && _percentages<100, "percent set error!");
        persons.push(Payee(payable(_beneficiaries), _percentages));
    }

    /**
     * 添加经销商、保存分账信息，绑定市场人员
     */
    function addDistributorInfo(address payable _personAddress, address[] memory _distributorAddress) public onlyOwner {

        // 判断市场人员,添加经销商时可能存在不挂靠市场人员情况，因入参不为空需传入address(0x0)
        if (_personAddress==address(0x0)) {

            // 保存经销商信息
            for(uint256 i=0;i<_distributorAddress.length; i++) {
                distributorInfo.push(Distributor(payable(_distributorAddress[i]), _personAddress));
                // 添加时默认 20%
                _addDistributorPayee(payable(_distributorAddress[i]), 20);
            }

        } else {

            // 判断地址是否存在
            require(checkPersonAddress(_personAddress), "person address not exist!");

            // 保存经销商与市场人员信息，并且设置经销商比例
            Distributor[] storage _distributor = affiliated[_personAddress];
            for(uint256 i=0;i<_distributorAddress.length; i++) {

                distributorInfo.push(Distributor(payable(_distributorAddress[i]), _personAddress));
                _distributor.push(Distributor(payable(_distributorAddress[i]), _personAddress));

                // 添加时默认 20%
                _addDistributorPayee(payable(_distributorAddress[i]), 20);
            }
        }
    }

    /**
     * 添加经销商地址和比例
     */
    function _addDistributorPayee(address payable _beneficiaries, uint16 _percentages) private {
        require(!checkDistributorAddress(_beneficiaries), "Distributor address has exist!");
        distributors.push(Payee(payable(_beneficiaries), _percentages));
    }

    /**
     * 删除经销商
     */
    function delDistributor(address payable _distributorAddress) public {

        // 判断经销商信息
        require(checkDistributorAddress(_distributorAddress), "distributor address not exist!");

        // 删除经销商信息并删除关联关系
        address payable personAddress;
        for(uint256 i=0; i<distributorInfo.length; i++) {
            if (distributorInfo[i].beneficiary == _distributorAddress) {
                if (distributorInfo[i].personAddress != address(0x0)) {
                    personAddress = distributorInfo[i].personAddress;
                }
                delete distributorInfo[i];              
            }
        }

        // 删除关联关系
        if (personAddress != address(0x0)) {
            Distributor[] storage distributorArr = affiliated[personAddress];
            for (uint256 i=0; i<distributorArr.length; i++) {
                if (distributorArr[i].beneficiary == _distributorAddress) {
                    delete affiliated[personAddress][i];
                }
            }
        }

        // 删除经销商分配比例，待确认是否删除
        for(uint256 i=0; i<distributors.length; i++) {
            if (distributors[i].beneficiary == _distributorAddress) {
                delete distributors[i];
            }
        }
    }

    /**
     * 删除市场人员
     */
    function delPerson(address payable _personAddress) public {

        // 判断市场人员信息是否存在
        require(checkPersonAddress(_personAddress), "person address not exist!");
        // 判断是否人员是否存在关联关系
        require(checkAffiliatedByAddress(_personAddress), "person affiliated not exist");

        // 删除经销商信息并删除关联关系
        for(uint256 i=0; i<distributorInfo.length; i++) {
            if (distributorInfo[i].personAddress == _personAddress) {
                delete distributorInfo[i];              
            }
        }

        // 删除关联关系
        delete affiliated[_personAddress];
    }


    /**
     * 更新预留出金比例
     */
    function updateReservePercent(uint16 _percentages) public onlyOwner {
        require(_percentages>0 && _percentages<100, "percent set error!");
        reserve.percentage = _percentages;
    }

    /**
     * 更新平台账户比例
     */
    function updatePlatformPercent(uint16 _percentages) public onlyOwner {
        require(_percentages>0 && _percentages<100, "percent set error!");
        platform.percentage = _percentages;
    }

    /**
     * 更新经销商的比例
     */
    function updateDistributorsPercent(address payable _distributorAddress, uint16 _percent) public onlyOwner {
        require(checkDistributorAddress(_distributorAddress), "distributor address not exist!");
        require(_percent>0 && _percent<100, "percent set error!");
        for (uint256 i=0; i<distributors.length; i++) {
            if (distributors[i].beneficiary == _distributorAddress) {
                distributors[i].percentage = _percent;
                break;
            }
        }
    }

    /**
     * 更新市场人员比例
     */
    function updatePersonsPercent(address payable _personsAddress, uint16 _percent) public onlyOwner {
        require(checkPersonAddress(_personsAddress), "persons address not exist!");
        require(_percent>0 && _percent<100, "percent set error!");
        for (uint256 i=0; i<persons.length; i++) {
            if (persons[i].beneficiary == _personsAddress) {
                persons[i].percentage = _percent;
                break;
            }
        }
    }


    /**
     * 分账
     */
    function splitAccount(uint256 _orderId, uint256 _amount, address payable _distributorAddress) public {

        // 校验订单是否已存在
        require(!checkOrders(_orderId), "order has exist!");

        // 判断经销商信息
        require(checkDistributorAddress(_distributorAddress), "distributor address not exist!");

        // 保存订单信息
        orders.push(Order(_orderId, _distributorAddress, payable(msg.sender), _amount));

        // 分账
        // 获取该笔订单下各得利者分成比例
        Share memory share = _getShare(_orderId, _amount, _distributorAddress);

        // 1.经销商
        console.log("amount:", _amount);
        console.log("share.distributor:", share.distributor);
        uint256 _distributorAmount = _amount * (share.distributor * 100) / 10000; // 小数运算扩大倍数，即：100.00 => 10000
        console.log("_distributorAmount:", _distributorAmount);
        IERC20(usdtAddress).transferFrom(msg.sender, share.distributorAddress, _distributorAmount);

        // 2.市场人员
        uint256 _presonAmount = 0;
        if (share.person!=0) {
            console.log("share.reserve: ", share.person);
            _presonAmount = _amount * (share.person * 100) / 10000;
            console.log("_presonAmount:", _presonAmount);
            if (_presonAmount>0) {
                IERC20(usdtAddress).transferFrom(msg.sender, share.personAddress, _presonAmount);
            }
        }

        // 3.预留
        console.log("share.reserve: ", share.reserve);
        uint256 _reserveAmount = _amount * (share.reserve * 100) / 10000;
        console.log("_reserveAmount:", _reserveAmount);
        IERC20(usdtAddress).transferFrom(msg.sender, share.reserveAddress, _reserveAmount);

        // 4.平台
        uint256 _platformAmount = (_amount - _distributorAmount - _presonAmount - _reserveAmount);
        console.log("_platformAmount:", _platformAmount);
        IERC20(usdtAddress).transferFrom(msg.sender, share.platformAddress, _platformAmount);

        // 记录事件
        emit splitAccountEevent(_orderId, _amount, _distributorAddress, share);
    }
    
    /**
     * 获取当前订单分成比例
     */
    function _getShare(uint256 _orderId, uint256 _amount, address payable _distributorAddress) internal returns(Share memory)  {

        // 取出经销商信息
        uint16 _distributorPrecent = 0; // 默认值
        for(uint256 i=0; i<distributors.length; i++) {
            if (distributors[i].beneficiary == _distributorAddress) {
                _distributorPrecent = distributors[i].percentage;
                break;
            }
        }

        // 经销商对应的市场人员
        uint16 _personPrecent = 0; // 默认值
        address payable _personAddress;
        for(uint256 i=0; i<distributorInfo.length; i++) {
            if (distributorInfo[i].beneficiary == _distributorAddress
                && distributorInfo[i].personAddress != address(0x0)) {
                bool result = false;
                for (uint256 j=0; j<persons.length; j++) {
                    if (persons[j].beneficiary == distributorInfo[i].personAddress) {
                        _personAddress = persons[j].beneficiary;
                        _personPrecent = persons[j].percentage;
                        result = true;
                        break;
                    }
                }
                if (result) {
                    break;
                }
            }
        }

        // 如果没有市场人员则市场人员份额分配到平台上
        uint16 _platformPrecent = platform.percentage;
        if (_personPrecent == 0) {
            _platformPrecent = (100 - reserve.percentage - _distributorPrecent);
        }

        // 保存当前订单分成比例
        shares[_orderId] = Share(_orderId, _amount, reserve.beneficiary, reserve.percentage, platform.beneficiary, _platformPrecent, _distributorAddress, _distributorPrecent, _personAddress, _personPrecent);
        return Share(_orderId, _amount, reserve.beneficiary, reserve.percentage, platform.beneficiary, _platformPrecent, _distributorAddress, _distributorPrecent, _personAddress, _personPrecent);
    }


    /**
     * 判断市场人员地址是否存在
     */
    function checkPersonAddress(address payable _personAddress) public view returns(bool)  {
        bool result;
        for(uint256 i=0; i<persons.length; i++) {
            if (persons[i].beneficiary == _personAddress) {
                result = true;
                break;
            }
        }
        return result;
    }

    /**
     * 判断经销商地址是否存在
     */
    function checkDistributorAddress(address payable _distributorAddress) public view returns(bool)  {
        bool result;
        for(uint256 i=0; i<distributors.length; i++) {
            if (distributors[i].beneficiary == _distributorAddress) {
                result = true;
                break;
            }
        }
        return result;
    }

    /**
     * 判断订单是否存在
     */
    function checkOrders(uint256 _orderId) public view returns(bool) {
        bool result;
        for(uint256 i=0; i<orders.length; i++) {
            if (orders[i].orderId == _orderId) {
                result = true;
                break;
            }
        }
        return result;
    }


    /**
     * 判断关联关系
     */
    function checkAffiliatedByAddress(address payable _personAddress) public view returns(bool) {
        bool result;
        if (affiliated[_personAddress].length>0) {
            result = true;
        }
        return result;
    }

}
