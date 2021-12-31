const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("IDO", function () {
  it("IDO work flow test", async function () {
    const idoSigner = ethers.provider.getSigner(0);
    const otherSigner = ethers.provider.getSigner(1);
    const userSigner = ethers.provider.getSigner(2);
    const presellMax = "1000000000000000000000000000"
    const userUsdtAmount = 1000000000000
    const totalSupplyMax = "1000000000000000000000000000000000000000"

    // Tether Deploy
    const Tether = await ethers.getContractFactory("TetherToken", otherSigner);
    const tether = await Tether.deploy(totalSupplyMax, "Tether", "USDT", 8);
    await tether.deployed();
    const tetherAddress = tether.address
    console.log("Tether Deploy", tetherAddress)

    // 给客户转一些usdt，用户能够用usdt在ido里面买lkk
    console.log("user approve usdt to ido")
    await tether.transfer(await userSigner.getAddress(), userUsdtAmount)

    //LKK Deploy
    const LKK = await ethers.getContractFactory("LKKToken", otherSigner);
    const lkk = await LKK.deploy(totalSupplyMax);
    await lkk.deployed();
    const lkkAddress = lkk.address;
    console.log("LKK Deploy", lkkAddress)

    // balanceOf
    let balance = await lkk.balanceOf(await otherSigner.getAddress())
    console.log("lkk balanceOf ", await otherSigner.getAddress(), balance.toString())

    // IDO Deploy
    const IDO = await ethers.getContractFactory("IDO", idoSigner);
    const ido = await IDO.deploy("IDO #01", "1000000000000000000000000000000000", tetherAddress, lkkAddress);
    await ido.deployed();
    const idoAddress = ido.address
    console.log("IDO Deploy", idoAddress)


    // 用户用usdt给ido合约授权
    console.log("user approve usdt to ido")
    await tether.connect(userSigner).approve(idoAddress, ethers.constants.MaxUint256)
    console.log("check usdt allowance ido", await userSigner.getAddress(), idoAddress, (await tether.allowance(await userSigner.getAddress(), idoAddress)).toString())

    // lkk 给 ido 合约授权，这样 ido 就能把钱 dposit 进自己了。
    console.log("lkk approve ido")
    await lkk.approve(idoAddress, ethers.constants.MaxUint256)

    let allowance = await lkk.allowance(await otherSigner.getAddress(), idoAddress)
    console.log("check allowance", await otherSigner.getAddress(), idoAddress, allowance.toString())

    // 存钱进ido合约
    await ido.dposit(await otherSigner.getAddress(), presellMax)

    // 查看ido合约是否到账
    expect(await lkk.balanceOf(idoAddress)).to.equal(presellMax);

    // 从ido合约用原生币购买lkk
    console.log("before buyWithOriToken lkk amount", await lkk.balanceOf(await userSigner.getAddress()))
    await ido.connect(userSigner).buyWithOriToken({ value: "1000000000000000000" })
    console.log("after buyWithOriToken lkk amount", await lkk.balanceOf(await userSigner.getAddress()))

    // 从ido合约用usdt买lkk
    console.log("before buyWithUSDT lkk amount", await lkk.balanceOf(await userSigner.getAddress()))
    console.log("before buyWithUSDT usdt amount", await tether.balanceOf(await userSigner.getAddress()))
    await ido.connect(userSigner).buyWithUSDT(888888) // 不能直接一把梭全买了，usdt还要扣手续费
    console.log("after buyWithUSDT lkk amount", await lkk.balanceOf(await userSigner.getAddress()))
    console.log("after buyWithUSDT usdt amount", await tether.balanceOf(await userSigner.getAddress()))
  });
});
