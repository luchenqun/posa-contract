// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { ethers } = hre
const { utils } = ethers;
const config = require("./config.js")
let { usdtCfg, lkkCfg, idoCfg, preSellCfg, gameItemCfg, gameItemSellCfg, nftSaleConfig, mosaicNFTCfg, changerMachineConfig } = config

const toWei = (ether) => {
  return utils.parseEther(String(ether)).toString()
}

async function main() {
  let usdtAddress, lkkAddress, gameItemAddress;

  // usdt 合约
  if (!usdtCfg.address) {
    const Tether = await ethers.getContractFactory("BEP20USDT", usdtCfg.signer);
    const tether = await Tether.deploy();
    await tether.deployed();
    usdtAddress = tether.address
    console.log("Tether Deploy", usdtAddress)
  } else {
    usdtAddress = usdtCfg.address
  }

  // lkk 合约部署
  if (!lkkCfg.address) {
    const LKK = await ethers.getContractFactory("LKKToken", lkkCfg.signer);
    const totalSupplyMax = toWei(10000000000)
    const lkk = await LKK.deploy("Little King Kong", "LKK", totalSupplyMax, "0x10ed43c718714eb63d5aa57b78b54704e256024e", usdtAddress);
    await lkk.deployed();
    lkkAddress = lkk.address;
    console.log("LKK Deploy", lkkAddress)
  } else {
    lkkAddress = lkkCfg.address
  }

  // ido 合约部署
  if (!(idoCfg.address)) {
    const IDO = await ethers.getContractFactory("IDO", idoCfg.signer);
    const { name, targets, percentages, presellMax, beginTime, endTime, perMinBuy, perMaxBuy, limitBuy, releaseRatio,
      lockTime, deblockCount, oriTokenToLkkRationNumerator, oriTokenToLkkRationDenominator,
      usdtToLkkRationNumerator, usdtToLkkRationDenominator,delockRatio,perBlockTime } = idoCfg;
    const ido = await IDO.deploy(name, usdtAddress, lkkAddress, targets, percentages,
      [presellMax, beginTime, endTime, perMinBuy, perMaxBuy, limitBuy, releaseRatio, lockTime, deblockCount,
         oriTokenToLkkRationNumerator, oriTokenToLkkRationDenominator, usdtToLkkRationNumerator, usdtToLkkRationDenominator,delockRatio,perBlockTime]);
    await ido.deployed();
    idoAddress = ido.address
    console.log("IDO Deploy", idoAddress)
  } else {
    idoAddress = idoCfg.address
    console.log("IDO old address", idoAddress)
  }

  // preSell 合约部署
  if (!preSellCfg.address) {
    const PreSell = await ethers.getContractFactory("PreSell", preSellCfg.signer);
    // 参数顺序
    // _usdtAddress targets[] percentages[] presellMax beginTime endTime perMinBuy perMaxBuy limitBuy
    let { targets, percentages, presellMax, beginTime, endTime, perMinBuy, perMaxBuy, limitBuy, oriTokenToPreSell, usdtToPreSell } = preSellCfg
    const params = [presellMax, beginTime, endTime, perMinBuy, perMaxBuy, limitBuy, oriTokenToPreSell, usdtToPreSell]
    const preSell = await PreSell.deploy(usdtAddress, targets, percentages, params);
    console.log("preSell Deploy", preSell.address)
  }

  // GameItem 合约部署
  if (!gameItemCfg.address) {
    const GameItem = await ethers.getContractFactory("GameItem", gameItemCfg.signer);
    const gameItem = await GameItem.deploy();
    await gameItem.deployed();
    gameItemAddress = gameItem.address;
    console.log("GameItem Deploy", gameItemAddress)
  } else {
    gameItemAddress = gameItemCfg.address;
  }

  // GameItem 合约部署
  if (!gameItemSellCfg.address) {
    const GameItemSell = await ethers.getContractFactory("GameItemSell", gameItemSellCfg.signer);
    const { issuerAddress, presellMax, targets, percentages, beginTime, endTime, perMinBuy, perMaxBuy, limitBuy, oriTokenToGameItem, usdtToGameItem, lkkToGameItem } = gameItemSellCfg

    const params = [presellMax, beginTime, endTime, perMinBuy, perMaxBuy, limitBuy, oriTokenToGameItem, usdtToGameItem, lkkToGameItem]
    let gameItemSell = await GameItemSell.deploy(usdtAddress, lkkAddress, gameItemAddress, issuerAddress, targets, percentages, params);

    await gameItemSell.deployed();
    const gameItemSellAddress = gameItemSell.address
    console.log("GameItemSell Deploy", gameItemSellAddress)
  }

  // NFTSale 合约部署
  if (!nftSaleConfig.address) {
    const NFTSale = await ethers.getContractFactory("NFTSale", nftSaleConfig.signer);
    const { fee, priceTokens, beneficiaries, percentages } = nftSaleConfig
    sale = await NFTSale.deploy(fee, priceTokens, beneficiaries, percentages);
    await sale.deployed();
    const nftSaleAddress = sale.address
    console.log("NFTSale deployed to:", nftSaleAddress);
  }

  // mosaicNFT 合约部署
  if (!mosaicNFTCfg.address) {
    const baseUrl = "https://ido.tst.qianqianshijie.com/"; // 默认配置地址
    const NFT = await ethers.getContractFactory("MosaicNFT", mosaicNFTCfg.signer);
    nft = await NFT.deploy("mosaic","mosaic", baseUrl);
    await nft.deployed();
    console.log("MosaicNFT deployed to:", nft.address);
    MINTER_ROLE = await nft.MINTER_ROLE();
    console.log("MosaicNFT MINTER_ROLE Hash:", MINTER_ROLE);
  }

  // ChangerMachine 合约部署
  if (!changerMachineConfig.address) {
    const ChangerMachine = await ethers.getContractFactory("ChangerMachine", mosaicNFTCfg.signer);
    const { beneficiaries, percentages } = changerMachineConfig
    changerMachine = await ChangerMachine.deploy(usdtAddress, beneficiaries, percentages);
    await changerMachine.deployed();
    console.log("ChangerMachine deployed to:", changerMachine.address);
  }

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
