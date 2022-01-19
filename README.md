# 开发环境安装
* 安装[Node.js](https://nodejs.org/zh-cn/)。建议安装最新版16.x的即可。
* 执行命令`npm i yarn -g`安装全局yarn。
* 在项目目录，执行命令`yarn`命令安装所需依赖。
* 执行命令 `yarn compile` 执行合约部署。
* 执行命令 `yarn test` 运行 test 目录下面的脚本。

开发环境是基于[Hardhat](https://learnblockchain.cn/docs/hardhat/getting-started/)，为什么选择Hardhat：**Hardhat内置了Hardhat网络，这是一个专为开发设计的本地以太坊网络。主要功能有Solidity调试，跟踪调用堆栈、console.log()和交易失败时的明确错误信息提示等**。

# 单元测试
执行`yarn test` 执行 test 目录下面所有的测试用例。如果要运行某个脚本文件，比如只运行`preSell.js`指定文件即可。如：`yarn test ./test/preSell.js`

其中 `business.js` 为一个正常的业务流程。其他的按照合约名字起名对每个合约进行单元测试。

# 扁平化处理
为了方便开发，合约以模块化的代码分散在各个文件夹。但是提交到线上浏览器如etherscan的时候，需要将文件进行扁平化提交。执行命令 `yarn flatten ./contracts/PreSell.sol > ./flatten/PreSell.sol` 即可将合约`PreSell.sol` 进行扁平化到flatten目录。当然，扁平化的合约还要稍加处理一下才能通过编译。

# IDO合约实现目标
业务场景简要描述：游戏公司已经发行了一个ERC20的LKK合约，我们需要通过IDO合约，将这些LKK代币分批出售。用户可以使用链上的原生币以及USDT来购买LKK，购买后LKK币，买了之后用户立即可以获得购买的LKK币的一部分。其他的LKK币锁在IDO合约里面，经过一个锁定期后，用户可以逐渐从IDO合约里面解锁LKK币。

LKK 代币合约地址以及 USDT 代币合约地址游戏方后续都会给到我们。我们为了搭建整套环境，使用`contracts\TetherToken.sol`模拟USDT代币合约，使用`contracts\LKKToken.sol`模拟LKK代币合约。

# IDO 合约接口说明
建议先了解整个业务逻辑，结合合约代码`contracts\IDO.sol`查阅接口。现在将`IDO.sol`合约一些重要的接口做个简单说明。由于接口后续开发可能会变，建议以合约代码为准。

## 变量说明
变量都声明在构造函数前面，后面有一定的注释。

# 一些有用的命令
```shell
npx hardhat accounts
npx hardhat compile
npx hardhat clean
npx hardhat test
npx hardhat node
node scripts/sample-script.js
npx hardhat help
```

# Ethereum 私链搭建
使用我发的geth.rar压缩包搭建。

# EthTool使用

## 增加常用ABI
进入 http://eth.lucq.fun/#/update-cache 选择`增加内置ABI`，将合约编译出来JSON文件复制进去。

## 合约操作
进入 http://eth.lucq.fun/#/contract 可对合约部署，调用(红：需要传原生token，黄：send调用，绿：call调用)，MetaMask调用。

## 交易查看
进入 http://eth.lucq.fun/#/transactions 查看列表。如果在合约操作页面已经填了对应的合约信息，点击合约查看合约交易解码，事件解码。

## 缓存
```json

```

# 部署
* 将目录`scripts\config.default.js`复制一份文件为`scripts\config.js`。
* 在`hardhat.config.js`文件里面配置好节点信息。
* 修改`scripts\config.js`文件参数，`signer`为部署该合约的私钥。`address`为合约地址。如果需要部署此合约，请将该字符串置为空串。如果不需要部署该合约，则将合约在节点上的正确地址填上去。
* 执行命令`yarn deploy --network bsc`，其中`bsc`为你在`hardhat.config.js`配置的节点信息，根据你自己的实际情况变化。

