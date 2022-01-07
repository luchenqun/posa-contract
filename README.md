# 开发环境安装
* 安装[Node.js](https://nodejs.org/zh-cn/)。建议安装最新版16.x的即可。
* 执行命令`npm i yarn -g`安装全局yarn。
* 在项目目录，执行命令`yarn`命令安装所需依赖。
* 执行命令 `yarn compile` 执行合约部署。
* 执行命令 `yarn test` 运行 test 目录下面的脚本。

开发环境是基于[Hardhat](https://learnblockchain.cn/docs/hardhat/getting-started/)，为什么选择Hardhat：**Hardhat内置了Hardhat网络，这是一个专为开发设计的本地以太坊网络。主要功能有Solidity调试，跟踪调用堆栈、console.log()和交易失败时的明确错误信息提示等**。

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
