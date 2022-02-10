const { expect } = require("chai");
const { ethers } = require("hardhat");
const assert = require('assert');
const { MyUtil } = require('./utils');
const myUtil = new MyUtil();


describe("NFTSaleTest", function () {

  const issuer = ethers.provider.getSigner(0); // Sale部署用户
  const user1 = ethers.provider.getSigner(1); // 普通用户
  let issuerAddress;
  let user1Address;

  let sale;
  // 准备环境
  before(async function () {
    issuerAddress = await issuer.getAddress();
    user1Address = await user1.getAddress();

    const params = {
      fee: 5000,
      priceTokens: ['0x0000000000000000000000000000000000000000'],
      beneficiaries: ['0x73519Cc1F5220Dd61eCE843d358b6EA612F3BA2d','0x6bDb39238869c5FBb3d5f66CD7732F1cE16a73b0'],
      percentages: [20,80]
    }

    const NFTSale = await ethers.getContractFactory("NFTSale");
    sale = await NFTSale.deploy(params.fee,params.priceTokens,params.beneficiaries,params.percentages);
    await sale.deployed();
    console.log("NFTSale deployed to:", sale.address);
  });

  it("query sale", async function () {
    console.log("sale paused",await sale.paused());
  })

});
