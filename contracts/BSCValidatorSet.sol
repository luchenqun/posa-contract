// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
import "hardhat/console.sol";

contract BSCValidatorSet {
    uint256 public constant EPOCH = 100;

    // PoSA 实现
    uint256 public constant NUM_OF_MINER = 4;
    enum Type {
        Stake,
        Delegate
    }

    struct Record {
        Type t; // 类型
        address node; // 质押节点地址
        address user; // 质押或投票人地址
        uint256 amount; // 质押或者投票金额
        uint256 time; // 时间
        bool back; // 钱是否取回来了
    }

    // 排序用一下
    struct Item {
        address node;
        uint256 amount;
    }

    mapping(uint256 => Record[]) public records; // epoch ==> Records 质押与委托记录
    address[] tempNodes;

    // 质押
    function stake(address node) external payable {
        require((block.number + (1 % EPOCH)) != 0, "soon in the next epoch, forbid stake");
        uint256 epochIndex = (block.number > 0 ? block.number - 1 : 0) / EPOCH;
        Record[] storage _records = records[epochIndex];
        _records.push(Record(Type.Stake, node, msg.sender, msg.value, block.timestamp, false));
    }

    // 委托
    function delegate(address node) external payable {
        require((block.number + (1 % EPOCH)) != 0, "soon in the next epoch, forbid delegate");
        require(hasCandidate(node, block.number) == true, "Candidate is not exit");
        uint256 epochIndex = (block.number > 0 ? block.number - 1 : 0) / EPOCH;
        Record[] storage _records = records[epochIndex];
        _records.push(Record(Type.Delegate, node, msg.sender, msg.value, block.timestamp, false));
    }

    // 撤销
    function withdraw(uint256 epochIndex) external payable {
        uint256 curEpochIndex = block.number / EPOCH;
        require(curEpochIndex > epochIndex, "please withdraw in next epoch");
        
        Record[] storage _records = records[epochIndex];
        uint256 amount = 0;
        for (uint256 i = 0; i < _records.length; i++) {
            address curUser = _records[i].user;
            bool back = _records[i].back;
            amount += (curUser == msg.sender && !back) ? _records[i].amount : 0;
            _records[i].back = true;
        }
        payable(msg.sender).transfer(amount);
    }

    // 质押与委托金额之和
    function totalAmount(address node, uint256 number) public view returns (uint256) {
        uint256 epochIndex = number / EPOCH;
        Record[] storage _records = records[epochIndex];
        uint256 amount = 0;
        for (uint256 i = 0; i < _records.length; i++) {
            address curNode = _records[i].node;
            amount += curNode == node ? _records[i].amount : 0;
        }
        return amount;
    }

    // 获取候选人列表
    function getCandidatesByBlockNumber(uint256 number) public view returns (address[] memory) {
        uint256 epochIndex = number / EPOCH;
        Record[] storage _records = records[epochIndex];
        address[] memory nodes = new address[](_records.length);
        uint256 length = 0;

        for (uint256 i = 0; i < _records.length; i++) {
            address curNode = _records[i].node;
            bool find = false;
            for (uint256 j = 0; j < nodes.length; j++) {
                if (curNode == nodes[j]) {
                    find = true;
                    break;
                }
            }

            Type t = _records[i].t;
            if (!find && t == Type.Stake) {
                nodes[length++] = curNode;
            }
        }

        address[] memory ans = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            ans[i] = nodes[i];
        }

        return ans;
    }

    // 获选人是否存在
    function hasCandidate(address node, uint256 number) public view returns (bool) {
        uint256 epochIndex = number / EPOCH;
        Record[] storage _records = records[epochIndex];
        for (uint256 i = 0; i < _records.length; i++) {
            address curNode = _records[i].node;
            Type t = _records[i].t;
            if (node == curNode && t == Type.Stake) {
                return true;
            }
        }
        return false;
    }

    function getValidatorsByBlockNumber(uint256 number) public view returns (address[] memory) {
        require(number <= block.number, "can not query future validators");
        uint256 epochIndex = number / EPOCH;
        address[] memory consensusAddrs = new address[](NUM_OF_MINER);
        // console.log("epochIndex", epochIndex);

        // 第一轮写死
        if (epochIndex == 0 && (number + 1) % EPOCH != 0) {
            consensusAddrs[0] = 0x00000Be6819f41400225702D32d3dd23663Dd690;
            consensusAddrs[1] = 0x1111102Dd32160B064F2A512CDEf74bFdB6a9F96;
            consensusAddrs[2] = 0x2222207B1f7b8d37566D9A2778732451dbfbC5d0;
            consensusAddrs[3] = 0x33333BFfC67Dd05A5644b02897AC245BAEd69040;
        } else {
            // 从上一轮的候选列表里面找出当前轮的出块人
            if ((number + 1) % EPOCH == 0) {
                number = number + 1; // 下一轮要确认出块节点了，比如一个EPOCH是20，那么在出第20个区块的时候，就会确定21 ~ 40的出块节点了
            }
            address[] memory nodes = getCandidatesByBlockNumber(number - EPOCH);
            Item[] memory items = new Item[](nodes.length);

            for (uint256 i = 0; i < nodes.length; i++) {
                items[i] = Item(nodes[i], totalAmount(nodes[i], number - EPOCH));
            }

            // for (uint256 i = 0; i < nodes.length; i++) {
            //     console.log("item", items[i].node, items[i].amount);
            // }

            for (uint256 i = 1; i < items.length; i++) {
                for (uint256 j = 0; j < i; j++) {
                    if (items[i].amount > items[j].amount || (items[i].amount == items[j].amount && items[i].node > items[j].node)) {
                        Item memory x = items[i];
                        items[i] = items[j];
                        items[j] = x;
                    }
                }
            }

            // 如果没人去参与质押，那么写死一批节点吧，不然没法玩了哦
            if (items.length < NUM_OF_MINER) {
                consensusAddrs[0] = 0x00000Be6819f41400225702D32d3dd23663Dd690;
                consensusAddrs[1] = 0x1111102Dd32160B064F2A512CDEf74bFdB6a9F96;
                consensusAddrs[2] = 0x2222207B1f7b8d37566D9A2778732451dbfbC5d0;
                consensusAddrs[3] = 0x33333BFfC67Dd05A5644b02897AC245BAEd69040;
            } else {
                for (uint256 i = 0; i < NUM_OF_MINER; i++) {
                    consensusAddrs[i] = items[i].node;
                }
            }
        }
        return consensusAddrs;
    }
}
