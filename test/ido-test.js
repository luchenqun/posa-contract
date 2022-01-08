const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("IDO", function () {
  it("IDO work flow test", async function () {
    const idoSigner = ethers.provider.getSigner(0); // ido部署方，我们自己
    const issuerSigner = ethers.provider.getSigner(1); // 发行方，指北京游戏发行方
    const userSigner = ethers.provider.getSigner(2); // 普通用户
    const idoSignerAddress = await idoSigner.getAddress();
    const issuerSignerAddress = await issuerSigner.getAddress();
    const userSignerAddress = await userSigner.getAddress();

    console.log("idoSigner address:", idoSignerAddress)
    console.log("issuerSigner address:", issuerSignerAddress)
    console.log("userSigner address:", userSignerAddress)

    console.log("==================================== IDO Test ====================================")

    const presellMax = "100000000000000000000000000000000000000000000000000000000000000000"
    const userUsdtAmount = "100000000"
    const totalSupplyMax = presellMax + "000"

    // Tether Deploy
    const Tether = await ethers.getContractFactory("TetherToken", issuerSigner);
    const tether = await Tether.deploy(totalSupplyMax, "Tether", "USDT", 8);
    await tether.deployed();
    const usdtAddress = tether.address
    console.log("Tether Deploy", usdtAddress)

    // 给客户转一些usdt，用户能够用usdt在ido里面买lkk
    console.log("transfer some undt to user")
    await tether.transfer(userSignerAddress, userUsdtAmount)

    //LKK Deploy
    const LKK = await ethers.getContractFactory("LKKToken", issuerSigner);
    const lkk = await LKK.deploy(totalSupplyMax);
    await lkk.deployed();
    const lkkAddress = lkk.address;
    console.log("LKK Deploy", lkkAddress)

    // balanceOf
    let balance = await lkk.balanceOf(issuerSignerAddress)
    console.log("lkk balanceOf ", issuerSignerAddress, balance.toString())

    // IDO Deploy
    const IDO = await ethers.getContractFactory("IDO", idoSigner);
    const now = parseInt(new Date().getTime() / 1000);
    let name = "IDO #01",
      // presellMax = "1000000000000000000000000000000000",
      // usdtAddress,
      // lkkAddress = lkkAddress,
      beginTime = 0,
      endTime = now + 6 * 30 * 24 * 3600,
      perMinBuy = 1,
      perMaxBuy = presellMax.substring(0, 28),
      limitBuy = presellMax.substring(0, 38),
      releaseRatio = 10,
      lockTime = 3 * 30 * 24 * 3600,
      deblockTime = 3 * 30 * 24 * 3600,
      deblockCount = 9,
      oriTokenToLkkRation = 100,
      usdtToLkkRation = 10;
    const ido = await IDO.deploy(name, usdtAddress, lkkAddress, [presellMax, beginTime, endTime, perMinBuy, perMaxBuy, limitBuy, releaseRatio, lockTime, deblockTime, deblockCount, oriTokenToLkkRation, usdtToLkkRation]);
    await ido.deployed();
    const idoAddress = ido.address
    console.log("IDO Deploy", idoAddress)

    // 用户用usdt给ido合约授权
    console.log("user approve usdt to ido")
    await tether.connect(userSigner).approve(idoAddress, ethers.constants.MaxUint256)
    console.log("check usdt allowance ido", userSignerAddress, idoAddress, (await tether.allowance(userSignerAddress, idoAddress)).toString())

    // lkk 给 ido 合约授权，这样 ido 就能把钱 dposit 进自己了。
    console.log("lkk approve ido")
    await lkk.approve(idoAddress, ethers.constants.MaxUint256)

    let allowance = await lkk.allowance(issuerSignerAddress, idoAddress)
    console.log("check allowance", issuerSignerAddress, idoAddress, allowance.toString())

    // 存钱进ido合约
    await ido.dposit(issuerSignerAddress, presellMax)

    // 查看ido合约是否到账
    expect(await lkk.balanceOf(idoAddress)).to.equal(presellMax);

    // 从ido合约用原生币购买lkk
    console.log("before buyWithOriToken lkk amount", await lkk.balanceOf(userSignerAddress))
    await ido.connect(userSigner).buyWithOriToken({ value: 10 })
    console.log("after buyWithOriToken lkk amount", await lkk.balanceOf(userSignerAddress))
    console.log("balanceDetail 0", await ido.balanceDetail(userSignerAddress, 0))

    // 从ido合约用usdt买lkk
    console.log("before buyWithUSDT lkk amount", await lkk.balanceOf(userSignerAddress))
    console.log("before buyWithUSDT usdt amount", await tether.balanceOf(userSignerAddress))
    await ido.connect(userSigner).buyWithUSDT(100)
    console.log("after buyWithUSDT lkk amount", await lkk.balanceOf(userSignerAddress))
    console.log("after buyWithUSDT usdt amount", await tether.balanceOf(userSignerAddress))
    console.log("balanceDetail 1", await ido.balanceDetail(userSignerAddress, 1))

    // 更新封闭期时长，让其可以立马解锁一部分
    await ido.connect(idoSigner).updateLockTime(0);

    // 获取用户可解锁的数量，应该等于 未解锁之和/deblockCount， (10 * 100 + 100 * 10) * 0.9 / 9 == 200
    let canDeblockBalance = await ido.canDeblockBalanceOf(userSignerAddress)
    console.log("canDeblockBalance", canDeblockBalance)

    // 解锁能解锁的所有Lkk币
    console.log("before deblockLkk amount", await lkk.balanceOf(userSignerAddress))
    await ido.connect(userSigner).deblockLkk(canDeblockBalance)
    console.log("after deblockLkk amount", await lkk.balanceOf(userSignerAddress))

    console.log("==================================== GameItemSell Test ====================================")
    // 部署一个ERC721的游戏道具合约
    const GameItem = await ethers.getContractFactory("GameItem", issuerSigner);
    const gameItem = await GameItem.deploy();
    await gameItem.deployed();
    const gameItemAddress = gameItem.address;
    console.log("GameItem Deploy", gameItemAddress)

    // 生产5个游戏道具，到时候用户用原生币，usdt, lkk 分别尝试去购买
    for (let i = 0; i < 5; i++) {
      await gameItem.safeMint(issuerSignerAddress, `https://example.com/${i}.json`)
    }

    // 部署一个预售游戏道具合约
    // IDO Deploy
    const GameItemSell = await ethers.getContractFactory("GameItemSell", idoSigner);
    let gameItemSell = null;
    let oriTokenToGameItem = 10,
      usdtToGameItem = 20,
      lkkToGameItem = 40;
    {
      // 参数顺序
      // usdtAddress lkkAddress gameItemAddress gameItemSupply : presellMax beginTime endTime perMinBuy perMaxBuy limitBuy oriTokenToGameItem usdtToGameItem lkkToGameItem
      const now = parseInt(new Date().getTime() / 1000);
      let
        presellMax = "100000000",
        beginTime = 0,
        endTime = now + 6 * 30 * 24 * 3600,
        perMinBuy = "1",
        perMaxBuy = "100",
        limitBuy = "10000";
      const params = [presellMax, beginTime, endTime, perMinBuy, perMaxBuy, limitBuy, oriTokenToGameItem, usdtToGameItem, lkkToGameItem]
      gameItemSell = await GameItemSell.deploy(usdtAddress, lkkAddress, gameItemAddress, issuerSignerAddress, params);
    }
    await gameItemSell.deployed();
    const gameItemSellAddress = gameItemSell.address
    console.log("GameItemSell Deploy", gameItemSellAddress)

    // 道具提供方给 gameItemSell 合约授权，这样 gameItemSell 就能把道具转移给用户了
    console.log("issuerSigner approve gameItemSell")
    await gameItem.setApprovalForAll(gameItemSellAddress, true)

    // 用户用usdt给gameItemSell合约授权
    console.log("user approve usdt to gameItemSell")
    await tether.connect(userSigner).approve(gameItemSellAddress, ethers.constants.MaxUint256)

    // 用户用lkk给gameItemSell合约授权
    console.log("user approve lkk to gameItemSell")
    await lkk.connect(userSigner).approve(gameItemSellAddress, ethers.constants.MaxUint256)

    // 购买测试
    {
      let tokenId = 0; // GameItem 索引从0开始

      // 用户使用原生币购买道具
      console.log("before buyWithOriToken gameItem owner:", await gameItem.ownerOf(tokenId))
      await gameItemSell.connect(userSigner).buyWithOriToken({ value: oriTokenToGameItem + 1 })
      console.log("after buyWithOriToken gameItem owner:", await gameItem.ownerOf(tokenId))
      tokenId++;

      console.log("before buyWithUSDT gameItem owner:", await gameItem.ownerOf(tokenId))
      await gameItemSell.connect(userSigner).buyWithUSDT(usdtToGameItem + 1)
      console.log("after buyWithUSDT gameItem owner:", await gameItem.ownerOf(tokenId))
      tokenId++;

      console.log("before buyWithLkk gameItem owner:", await gameItem.ownerOf(tokenId))
      await gameItemSell.connect(userSigner).buyWithLkk(lkkToGameItem + 1)
      console.log("after buyWithLkk gameItem owner:", await gameItem.ownerOf(tokenId))
      tokenId++;
    }
  });
});
