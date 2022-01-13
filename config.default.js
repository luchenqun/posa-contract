const { ethers } = require("hardhat");
const { utils } = ethers;

// 讲 ether 转为 wei
const toWei = (ether) => {
  return utils.parseEther(String(ether)).toString(10)
}

const now = parseInt(new Date().getTime() / 1000);

const params = {
  usdt: {
    address: "",
    decimals: 18
  },
  lkk: {
    address: "",
    decimals: 18
  },
  ido: {
    name: "IDO #01",
    presellMax: toWei("10000000000"),
    beginTime: 0,
    endTime: now + 6 * 30 * 24 * 3600,
    perMinBuy: toWei("1"),
    perMaxBuy: toWei("100000"),
    limitBuy: toWei("100000000"),
    releaseRatio: 0,
    lockTime: 0,
    deblockTime: 100 * 24 * 3600,
    deblockCount: 100,
    oriTokenToLkkRationNumerator: 500,
    oriTokenToLkkRationDenominator: 1,
    usdtToLkkRationNumerator: 125,
    usdtToLkkRationDenominator: 2,
  },
  preSell: {
    presellMax: "10000",
    beginTime: 0,
    endTime: now + 6 * 30 * 24 * 3600,
    // 下面是购买的个数，不要转为wei
    perMinBuy: "1",
    perMaxBuy: "10",
    limitBuy: "1000",
    oriTokenToPreSell: toWei(0.1),
    usdtToPreSell: toWei(500),
  },
  gameItemSell: {
    presellMax: "100000000",
    beginTime: 0,
    endTime: now + 6 * 30 * 24 * 3600,
    // 下面是购买的个数，不要转为wei
    perMinBuy: "1",
    perMaxBuy: "100",
    limitBuy: "10000",
    oriTokenToGameItem: toWei(0.01),
    usdtToGameItem: toWei(100),
    lkkToGameItem: toWei(1000),
  }
}

module.exports = params