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
        address: "",
        decimals: 18
    },
    lkkCfg: {
        signer: issuerSigner,
        address: "",
        decimals: 18
    },
    idoCfg: {
        signer: idoSigner,
        address: "",
        name: "IDO #01",
        targets: ["0x00000be6819f41400225702d32d3dd23663dd690", "0x1111102dd32160b064f2a512cdef74bfdb6a9f96"],
        percentages: [15, 85],
        presellMax: toWei("10000000000"),
        beginTime: 0,
        endTime: now + 6 * 30 * 24 * 3600,
        perMinBuy: toWei("1"),
        perMaxBuy: toWei("100000"),
        limitBuy: toWei("100000000"),
        releaseRatio: 10,
        lockTime: 0,
        deblockCount: 5,
        oriTokenToLkkRationNumerator: 500,
        oriTokenToLkkRationDenominator: 1,
        usdtToLkkRationNumerator: toWei("1"),
        usdtToLkkRationDenominator: toWei("0.016"),
        delockRatio: 20,
        perBlockTime: 120
    },
    preSellCfg: {
        signer: idoSigner,
        address: "",
        targets: ["0x00000be6819f41400225702d32d3dd23663dd690", "0x1111102dd32160b064f2a512cdef74bfdb6a9f96"],
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
        address: "",
    },
    gameItemSellCfg: {
        signer: idoSigner,
        address: "",
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
    },
    mosaicNFTCfg: {
        signer: idoSigner,
        address: "",
    },
    nftSaleConfig: {
        signer: idoSigner,
        address: "",
        fee: 5,
        priceTokens: ['0x0000000000000000000000000000000000000000', '0x3886949F10238a57E9fc929ce696d96271733023'],
        beneficiaries: ['0x73519Cc1F5220Dd61eCE843d358b6EA612F3BA2d','0x6bDb39238869c5FBb3d5f66CD7732F1cE16a73b0'],
        percentages: [20,80]
    },
    changerMachineConfig: {
        signer: idoSigner,
        address: "",
        beneficiaries: ['0x73519Cc1F5220Dd61eCE843d358b6EA612F3BA2d','0x6bDb39238869c5FBb3d5f66CD7732F1cE16a73b0'],
        percentages: [20,40]
    }
}

module.exports = params
