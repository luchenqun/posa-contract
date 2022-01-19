const { expect } = require("chai");
const { ethers } = require("hardhat");
const { utils, BigNumber } = ethers;

const sleep = time => {
  return new Promise(resolve => setTimeout(resolve, time));
};

const orderId = () => {
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
    endTime = now + 6 * 30 * 24 * 3600,
    // 下面是购买的个数，不要转为wei
    perMinBuy = 1,
    perMaxBuy = 3,
    limitBuy = 1000,
    oriTokenToPreSell = toWei(1),
    t1 = "0xeeeee5d1d01f99d760f9da356e683cc1f29f2f81",
    t2 = "0xfffff01adb78f8951aa28cf06ceb9b8898a29f50",
    p1 = 20,
    p2 = 80,
    usdtToPreSell = toWei(100);
  // 收钱地址以及收钱百分比
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

  it('User does not have USDT, purchase failed', async function () {
    await expect(preSell.connect(userSigner).buyWithUSDT(usdtToPreSell, orderId())).to.be.revertedWith("BEP20: transfer amount exceeds balance");
  });

  it('transfer some usdt to user', async function () {
    let preUsdt = await tether.balanceOf(userAddress);
    expect(preUsdt).to.equal(0);

    const transferAmount = toWei("1000")
    await tether.connect(issuerSigner).transfer(userAddress, transferAmount)

    let curUsdt = await tether.balanceOf(userAddress);
    expect(curUsdt).to.equal(transferAmount);
  });

  it('User does not allowance presell, purchase failed', async function () {
    await expect(preSell.connect(userSigner).buyWithUSDT(usdtToPreSell, orderId())).to.be.revertedWith("BEP20: transfer amount exceeds allowance");
  });

  it('User approve usdt to presell address', async function () {
    const approveAmount = BigNumber.from(usdtToPreSell).mul(10)
    await tether.connect(userSigner).approve(preSell.address, approveAmount)
    expect(await tether.allowance(userAddress, preSell.address)).to.equal(approveAmount)
  });

  it('buy with usdt success', async function () {
    const usdtAmount = BigNumber.from(usdtToPreSell).add(toWei(1)) // 传进去的usdt购买数量
    const usdtActual = usdtToPreSell // 实际应该扣数的数量

    // 购买前各个usdt余额
    const usdtUser = await tether.balanceOf(userAddress);
    const usdtT1 = await tether.balanceOf(t1);
    const usdtT2 = await tether.balanceOf(t2);
    const usdtToT1 = BigNumber.from(usdtActual).mul(p1).div(100)
    const usdtToT2 = BigNumber.from(usdtActual).sub(usdtToT1)
    const count = await preSell.balanceOf(userAddress)

    await preSell.connect(userSigner).buyWithUSDT(usdtAmount, orderId())

    expect(await preSell.balanceOf(userAddress)).to.equal(count + 1); // 优惠券总数增加一张
    expect(await tether.balanceOf(userAddress)).to.equal(BigNumber.from(usdtUser).sub(usdtActual)); // 扣除实际的usdt支出
    expect(await tether.balanceOf(t1)).to.equal(BigNumber.from(usdtT1).add(usdtToT1)); // 目标地址收到自己的百分比
    expect(await tether.balanceOf(t2)).to.equal(BigNumber.from(usdtT2).add(usdtToT2)); // 目标地址收到自己的百分比
  });

  it('buy with usdt should not great than per max buy', async function () {
    const count = perMaxBuy + 1;
    const usdtAmount = BigNumber.from(usdtToPreSell).mul(count)
    await expect(preSell.connect(userSigner).buyWithUSDT(usdtAmount, orderId())).to.be.revertedWith("PreSell: count must less than perMaxBuy");
  });

});
