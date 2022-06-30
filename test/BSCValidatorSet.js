const { expect } = require("chai");
const { ethers } = require("hardhat");
const { utils } = ethers;

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

const PrivatekeyNum = 8;
const Epoch = 100;

describe("BSCValidatorSet Test", function () {
  this.timeout(0)
  it("BSCValidatorSet work flow test", async function () {
    const signer = ethers.provider.getSigner(0);
    const signer2 = ethers.provider.getSigner(1);

    const signerAddress = await signer.getAddress();
    const node1 = signerAddress;
    console.log("signerAddress address:", signerAddress)

    console.log("==================================== BSCValidatorSet Test ====================================")

    // 合约部署
    // const ValidatorSet = await ethers.getContractFactory("BSCValidatorSet", signer);
    // const validatorSet = await ValidatorSet.deploy();
    // await validatorSet.deployed();
    // const validatorSetAddress = validatorSet.address
    // console.log("BSCValidatorSet Deploy Address", validatorSetAddress)

    const validatorSetAddress = "0x0000000000000000000000000000000000001000"
    const validatorSet = await ethers.getContractAt("BSCValidatorSet", validatorSetAddress, signer)

    {
      // 质押8个节点
      for (let i = 0; i < PrivatekeyNum; i++) {
        const signer = ethers.provider.getSigner(i);
        const node = await signer.getAddress()
        await validatorSet.connect(signer).stake(node, { value: toWei(10+i) });
        // await validatorSet.connect(signer).delegate(node, { value: toWei(1000+i*10) });
      }
      let blockNumber = await ethers.provider.getBlockNumber()

      for (let i = 0; i < PrivatekeyNum; i++) {
        const node = await ethers.provider.getSigner(i).getAddress();
        console.log(`节点 ${node} 质押+委托总金额为：`, await validatorSet.totalAmount(node, blockNumber))
      }

      // while (blockNumber - 1 <= Epoch) {
      //   console.log(`区块高度${blockNumber}候选节点：`, await validatorSet.getCandidatesByBlockNumber(blockNumber))
      //   console.log(`区块高度${blockNumber}出块节点：`, await validatorSet.getValidatorsByBlockNumber(blockNumber))
      //   await signer.sendTransaction({ to: "0x0000000000000000000000000000000000000000", value: 1 });
      //   blockNumber = await ethers.provider.getBlockNumber();
      // }

      // console.log("提取前合约余额", await ethers.provider.getBalance(validatorSetAddress))
      // console.log("提取前账户余额", await signer.getBalance())
      // await validatorSet.connect(signer).withdraw(0);
      // console.log("提取后合约余额", await ethers.provider.getBalance(validatorSetAddress))
      // console.log("提取后账户余额", await signer.getBalance())
    }

    // {
    //   // 质押
    //   console.log("质押前合约余额", await ethers.provider.getBalance(validatorSetAddress))
    //   console.log("质押前账户余额", await signer.getBalance())
    //   await validatorSet.connect(signer).stake(node1, { value: toWei(10) });
    //   console.log("质押后合约余额", await ethers.provider.getBalance(validatorSetAddress))
    //   console.log("质押后账户余额", await signer.getBalance());
    //   console.log()
    // }

    // {
    //   // 投票
    //   console.log("投票前合约余额", await ethers.provider.getBalance(validatorSetAddress))
    //   console.log("投票前账户余额", await signer2.getBalance())
    //   await validatorSet.connect(signer2).delegate(node1, { value: toWei(1) });
    //   console.log("投票后合约余额", await ethers.provider.getBalance(validatorSetAddress))
    //   console.log("投票后账户余额", await signer2.getBalance());
    //   console.log()
    // }


  });
});
