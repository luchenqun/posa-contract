const params = {
  usdt: {
    decimals: 18
  },
  lkk: {
    decimals: 18
  },
  ido: {
    perMinBuy: 1, // 单次最小购买量
    perMaxBuy: "10000000000000", // 单次最小购买量
    presellMax: "", // 预售总量
    perMinBuy: "", // 每次最低购买
    perMaxBuy: "", // 每次最大购买
    limitBuy: "", // 最大购买
    releaseRatio: "", // 购买释放比例
    lockTime: "", // 买了之后，封闭多长时间不允许提取，单位秒
    deblockTime: "", // 解锁时间长度，单位秒
    deblockCount: "", // 在 deblockTime 可线性解锁多少次
    oriTokenToLkkRation: "", // 原生 token 兑换 lkk 比例
    usdtToLkkRation: "", // usdt 兑换 lkk比例
  },
  gameItemSell: {
    presellMax: "", // 预售总量
    perMinBuy: "", // 每次最低购买多少个游戏道具
    perMaxBuy: "", // 每次最大购买多少个游戏道具
    limitBuy: "", // 最多购买多少个游戏道具
    oriTokenToGameItem: "", // 需要多少原生 token 购买一个道具
    usdtToGameItem: "", // 需要多少原生 usdt 购买一个道具
    lkkToGameItem: "", // 需要多少原生 LKK 购买一个道具
  }
}