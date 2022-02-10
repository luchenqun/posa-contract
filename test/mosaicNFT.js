const { expect } = require("chai");
const { ethers } = require("hardhat");
const assert = require('assert');
const { MyUtil } = require('./utils');
const myUtil = new MyUtil();


describe("MosaicNFTTest", function () {

  const issuer = ethers.provider.getSigner(0); // NFT部署用户
  const user1 = ethers.provider.getSigner(1); // 普通用户
  let issuerAddress;
  let user1Address;

  let nft;
  let MINTER_ROLE;
  const baseUrl = "http://192.168.31.160:8080/ipfs/";
  // 准备环境
  before(async function () {
    issuerAddress = await issuer.getAddress();
    user1Address = await user1.getAddress();

    const NFT = await ethers.getContractFactory("MosaicNFT");
    nft = await NFT.deploy("mosaic","mosaic",baseUrl);
    await nft.deployed();
    console.log("MosaicNFT deployed to:", nft.address);
    MINTER_ROLE = await nft.MINTER_ROLE();
    console.log("MosaicNFT MINTER_ROLE Hash:", MINTER_ROLE);
  });

  //先授权，再生成NFT token
  it("grant role and born mosaic", async function () {
    console.log("grant MINTER_ROLE to ",issuerAddress);
    //await nft.grantRole(MINTER_ROLE, issuerAddress);
    assert.ok(!await nft.hasRole(MINTER_ROLE, issuerAddress));
    //token构建参数
    const params = {
      orderId: "123456",
      name: "Sphinx",
      defskill1: "Wildwind Strike",
      defskill2: "Storm Body",
      defskill3: "Final Trial",
      defskill4: "Wind King Area",
      defstars: 5,
      element: 4,
      genes: myUtil.generateId(),
      owner: user1Address
    }
    //生成token
    const tx = await nft.bornMosaic(params.orderId, params.name,params.defskill1,params.defskill2,params.defskill3,params.defskill4,
        params.defstars,params.element,params.genes,params.owner);
    console.log("txHash:",tx.hash);
    const receipt = await tx.wait();
    assert.equal(receipt.status, 1);

    //获取事件ID
    const eventId = ethers.utils.id("MosaicBorned(uint256,address,uint256)");
    //获取mosaicId
    let mosaicId;
    for(let i=0;i<receipt.logs.length;i++){
      if(receipt.logs[i].topics[0] == eventId){
        mosaicId = myUtil.hexToNum(receipt.logs[i].topics[1]);
        console.log("mosaicId:",mosaicId);
      }
    }
    //获取token
    const mosaic = await nft.getMosaic(mosaicId);
    console.log("Mosaic body { name:%s,defskill1:%s,defskill2:%s,defskill3:%s,defskill4:%s,defstars:%s,element:%s,id:%s,genes:%s,bornAt:%s }",
       mosaic.name, mosaic.defskill1,mosaic.defskill2,mosaic.defskill3,mosaic.defskill4,mosaic.defstars,mosaic.element,mosaic.id,mosaic.genes,mosaic.bornAt);
    const tokenURI = await nft.tokenURI(mosaicId);
    console.log("tokenURI:"+tokenURI)
    assert.equal(baseUrl+mosaicId+"/"+myUtil.numToHex(params.genes)+".json", tokenURI);
  });

});
