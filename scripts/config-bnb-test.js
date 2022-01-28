const { ethers } = require("hardhat");
const { utils } = ethers;

const idoSigner = ethers.provider.getSigner(0); // ido部署方，我们自己
const issuerSigner = ethers.provider.getSigner(1); // 发行方，指北京游戏发行方

// 讲 ether 转为 wei
const toWei = (ether) => {
  return utils.parseEther(String(ether)).toString()
}

const now = parseInt(new Date().getTime() / 1000);

const params = {
  usdtCfg: {
    signer: issuerSigner,
    address: "0x337610d27c682e347c9cd60bd4b3b107c9d34ddd",
    decimals: 18
  },
  lkkCfg: {
    signer: issuerSigner,
    address: "0x5653d60294858D2BDFE832AFC9bD2325a59A634c",
    decimals: 18
  },
  idoCfg: {
    signer: idoSigner,
    address: "0x546bc6E008689577C69C42b9C1f6b4C923f59B5d",
    name: "IDO #01",
    targets: ["0x00000be6819f41400225702d32d3dd23663dd690", "0x1111102dd32160b064f2a512cdef74bfdb6a9f96"],
    percentages: [15, 85],
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
  preSellCfg: {
    signer: idoSigner,
    address: "",
    targets: ["0xeeeee5d1d01f99d760f9da356e683cc1f29f2f81", "0xfffff01adb78f8951aa28cf06ceb9b8898a29f50"],
    percentages: [15, 85],
    beginTime: 0,
    endTime: now + 6 * 30 * 24 * 3600,
    // 下面是购买的个数，不要转为wei
    presellMax: "10000",
    perMinBuy: "1",
    perMaxBuy: "10",
    limitBuy: "1000",
    oriTokenToPreSell: toWei(0.1),
    usdtToPreSell: toWei(500),
  },
  gameItemCfg: {
    signer: idoSigner,
    address: "0x6c0d1bdD05B0A96501e73448a83Fc7D40c6F50d2",
  },
  gameItemSellCfg: {
    signer: idoSigner,
    address: "0xb4936c57f5b6B5a247aD6089C56064DF98fFf470",
    issuerAddress: "0x00000be6819f41400225702d32d3dd23663dd690",
    targets: ["0x00000be6819f41400225702d32d3dd23663dd690", "0x1111102dd32160b064f2a512cdef74bfdb6a9f96"],
    percentages: [15, 85],
    beginTime: 0,
    endTime: now + 6 * 30 * 24 * 3600,
    // 下面是购买的个数，不要转为wei
    presellMax: "100000000",
    perMinBuy: "1",
    perMaxBuy: "100",
    limitBuy: "10000",
    oriTokenToGameItem: toWei(0.01),
    usdtToGameItem: toWei(100),
    lkkToGameItem: toWei(1000),
  }
}

module.exports = params