const { expect } = require("chai");
const { ethers} = require("hardhat");
const { utils, BigNumber } = ethers;


const sleep = time => {
  return new Promise(resolve => setTimeout(resolve, time));
};

const generateOrderId = () => {
  return new Date().getTime() + parseInt(Math.random() * 1000000);
}

// 讲 ether 转为 wei
const toWei = (ether) => {
  return utils.parseEther(String(ether)).toString()
}

describe("PreSell Unit Test", function () {
  this.timeout(6000) // 超时设置

  let tether, preSell; // 两个合约

  // preSell 合约参数
  let now = parseInt(new Date().getTime() / 1000),
    presellMax = "10000",
    beginTime = 0,
    endTime = now + 6 * 30 * 24 * 3600, //半年的秒数
    // 下面是购买的个数，不要转为wei
    perMinBuy = 1,  //每次最低购买多少个游戏道具
    perMaxBuy = 3,  //每次最大购买多少个游戏道具
    limitBuy = 1000, // 最多购买多少个游戏道具
    oriTokenToPreSell = toWei(1),  // 需要多少原生 token 购买一张入场券
    t1 = "0xeeeee5d1d01f99d760f9da356e683cc1f29f2f81",  //收款人
    t2 = "0xfffff01adb78f8951aa28cf06ceb9b8898a29f50",
    p1 = 20,  // 收款百分比
    p2 = 80,
    usdtToPreSell = toWei(100);  // 需要多少原生 usdt 购买一张入场券
  // 收钱地址以及收钱百分比, 每购买一次，都会向所有收款人转账的
  let targets = [t1, t2];
  let percentages = [p1, p2];

  const issuerSigner = ethers.provider.getSigner(1); // 发行方，指北京游戏发行方
  const userSigner = ethers.provider.getSigner(2); // 普通用户
  let issuerAddress;
  let userAddress;

  // 准备环境
  before(async function () {
    issuerAddress = await issuerSigner.getAddress();
    userAddress = await userSigner.getAddress();

    // Tether Deploy
    const Tether = await ethers.getContractFactory("BEP20USDT", issuerSigner);
    tether = await Tether.deploy();
    await tether.deployed();
    const userUsdtAmount = "1000000000000"
    await tether.mint(toWei(userUsdtAmount)) // 铸造USDT
    console.log("Tether Deploy", tether.address)

    // PreSell Deploy
    const params = [presellMax, beginTime, endTime, perMinBuy, perMaxBuy, limitBuy, oriTokenToPreSell, usdtToPreSell]
    const PreSell = await ethers.getContractFactory("PreSell", issuerSigner);
    preSell = await PreSell.deploy(tether.address, targets, percentages, params);
    console.log("preSell Deploy", preSell.address)
  });

  //测试构造函数参数是否设置
  it("Constructor parameters check",async function (){
    expect(await preSell.usdtAddress()).to.equal(tether.address);
    expect(await preSell.presellMax()).to.equal(presellMax);
    expect(await preSell.beginTime()).to.equal(beginTime);
    expect(await preSell.endTime()).to.equal(endTime);
    expect(await preSell.perMinBuy()).to.equal(perMinBuy);
    expect(await preSell.perMaxBuy()).to.equal(perMaxBuy);
    expect(await preSell.limitBuy()).to.equal(limitBuy);
    expect(await preSell.oriTokenToPreSell()).to.equal(oriTokenToPreSell);
    expect(await preSell.usdtToPreSell()).to.equal(usdtToPreSell);
    expect(await preSell.pause()).to.equal(false);
    for (let i = 0; i < targets.length; i++) {
        let payee = await preSell.payees(i);
        expect(payee.target).to.equal(utils.getAddress(targets[i]));
        expect(payee.percentage).to.equal(percentages[i]);
    }
  })
  //普通用户如果没有USDT,结果：购买失败
  it('User does not have USDT, purchase failed', async function () {
    await expect(preSell.connect(userSigner).buyWithUSDT(usdtToPreSell, generateOrderId())).to.be.revertedWith("BEP20: transfer amount exceeds balance");
  });

  //转一些USDT给普通用户
  it('transfer some usdt to user', async function () {
    let preUsdt = await tether.balanceOf(userAddress);
    expect(preUsdt).to.equal(0);

    const transferAmount = toWei("1000")
    await tether.connect(issuerSigner).transfer(userAddress, transferAmount)

    let curUsdt = await tether.balanceOf(userAddress);
    expect(curUsdt).to.equal(transferAmount);
  });

  //用户如果没有设置预售许可，结果：购买失败
  it('User does not allowance presell, purchase failed', async function () {
    await expect(preSell.connect(userSigner).buyWithUSDT(usdtToPreSell, generateOrderId())).to.be.revertedWith("BEP20: transfer amount exceeds allowance");
  });

  //用户许可USDT一定额度转到预售地址
  it('User approve usdt to presell address', async function () {
    const approveAmount = BigNumber.from(usdtToPreSell).mul(10)
    await tether.connect(userSigner).approve(preSell.address, approveAmount)
    expect(await tether.allowance(userAddress, preSell.address)).to.equal(approveAmount)
  });

  //用USDT购买成功测试，购买N张，并检查各合约账户余额前后变化是否与预期一致
  it('buy with usdt success', async function () {
    const buyNumber = 2;
    const usdtAmount = BigNumber.from(usdtToPreSell).mul(buyNumber); // 传进去的usdt购买数量,购买N张

    // 购买前各个usdt余额
    const usdtUser = await tether.balanceOf(userAddress);
    const usdtT1 = await tether.balanceOf(t1);
    const usdtT2 = await tether.balanceOf(t2);
    const usdtToT1 = BigNumber.from(usdtAmount).mul(p1).div(100)
    const usdtToT2 = BigNumber.from(usdtAmount).sub(usdtToT1)
    const count = await preSell.balanceOf(userAddress)

    const orderId = generateOrderId();
    await preSell.connect(userSigner).buyWithUSDT(usdtAmount, orderId);

    const nowCount = count.add(buyNumber);
    expect(await preSell.balanceOf(userAddress)).to.equal(nowCount); // 优惠券总数增加
    expect(await tether.balanceOf(userAddress)).to.equal(BigNumber.from(usdtUser).sub(usdtAmount)); // 扣除实际的usdt支出
    expect(await tether.balanceOf(t1)).to.equal(BigNumber.from(usdtT1).add(usdtToT1)); // 目标地址收到自己的百分比
    expect(await tether.balanceOf(t2)).to.equal(BigNumber.from(usdtT2).add(usdtToT2)); // 目标地址收到自己的百分比

    let orderDetail = await preSell.balanceDetailByOrderId(orderId);
    expect(await orderDetail.target).to.equal(userAddress);
    expect(await orderDetail.origin).to.equal(usdtAmount);
    expect(await orderDetail.currency).to.equal(1);
    expect(await orderDetail.toPreSell).to.equal(usdtToPreSell);
    expect(await orderDetail.orderId).to.equal(orderId);
    expect(await preSell.presellTotal()).to.equal(nowCount);
  });

  //使用USDT购买超过最大购买量，结果：失败
  it('buy with usdt should not great than per max buy', async function () {
    const count = perMaxBuy + 1;
    const usdtAmount = BigNumber.from(usdtToPreSell).mul(count)
    await expect(preSell.connect(userSigner).buyWithUSDT(usdtAmount, generateOrderId())).to.be.revertedWith("PreSell: count must less than perMaxBuy");
  });

  //使用原生币进行购买，并检查各账户余额前后变化是否与预期一致
  it("buy with origin coin",async function (){
    const buyNumber = 2;
    const originAmount = BigNumber.from(oriTokenToPreSell).mul(buyNumber); //根据原生币兑换比例，购买N张

    // 购买前各个原生币的余额 ethers.utils.formatEther(
    const originUser = await userSigner.getBalance();
    const originT1 = await ethers.provider.getBalance(t1);
    const originT2 = await ethers.provider.getBalance(t2);
    console.log("originUser:%s,originT1:%s,originT2:%s",originUser,originT1,originT2);
    const originToT1 = BigNumber.from(originAmount).mul(p1).div(100);
    const originToT2 = BigNumber.from(originAmount).sub(originToT1);
    console.log("originAmount detail:%s,originToT1:%s,originToT2:%s",originAmount,originToT1,originToT2);
    const count = await preSell.balanceOf(userAddress);//已购买张数
    const orderId = generateOrderId();
    const tx = await preSell.connect(userSigner).buyWithOriToken(orderId,{value:originAmount});
    console.log("txHash:",tx.hash);
    const receipt = await tx.wait();
    console.log("receipt:",receipt);
    const actualFee = receipt.cumulativeGasUsed.mul(receipt.effectiveGasPrice);
    console.log("actualFee:",actualFee);

    const nowCount = count.add(buyNumber);
    expect(await preSell.balanceOf(userAddress)).to.equal(nowCount); // 优惠券总数增加
    const nowOriginUser = await userSigner.getBalance();
    const nowT1 = await ethers.provider.getBalance(t1);
    const nowT2 = await ethers.provider.getBalance(t2);
    console.log("originUser:%s,nowT1:%s,nowT2:%s",nowOriginUser,nowT1,nowT2);
    console.log("originUser:%s, nowOriginUser:%s",originUser,nowOriginUser);
    console.log("%s - %s = %s",originUser,nowOriginUser,originUser.sub(nowOriginUser));

    expect(nowOriginUser).to.equal(originUser.sub(actualFee).sub(originAmount)); //当前余额 = 原始余额 - 手续费 - 购买金额
    expect(nowT1).to.equal(BigNumber.from(originT1).add(originToT1)); // 目标地址收到自己的百分比
    expect(nowT2).to.equal(BigNumber.from(originT2).add(originToT2)); // 目标地址收到自己的百分比

    const orderDetail = await preSell.balanceDetailByOrderId(orderId);
    expect(await orderDetail.target).to.equal(userAddress);
    expect(await orderDetail.origin).to.equal(originAmount);
    expect(await orderDetail.currency).to.equal(0);
    expect(await orderDetail.toPreSell).to.equal(oriTokenToPreSell);
    expect(await orderDetail.orderId).to.equal(orderId);
    expect(await preSell.presellTotal()).to.equal(nowCount);
  })

});
