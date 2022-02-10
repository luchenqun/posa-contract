### MosaicNFT ABI说明
#### Constructor
```
部署时构造函 
constructor(string name_,string symbol_,string baseURI_)
```


#### Event
```
将owner下的某个tokenId授权给approved时
Approval(address owner,address approved,uint256 tokenId)
将owner下的所有tokenId授权/取消授权给operator时
ApprovalForAll(address owner,address operator,bool approved)
新生成token
MosaicBorned(uint256 mosaicId_,address owner_,uint256 genes_)
更新token genes时
MosaicEvolved(uint256 mosaicId_,uint256 oldGenes_,uint256 newGenes_)
重设token genes时
MosaicRebirthed(uint256 mosaicId_,uint256 genes_)
销毁token时
MosaicRetired(uint256 mosaicId_)
转移owner所有权时
OwnershipTransferred(address previousOwner,address newOwner)
暂停时
Paused(address account)
角色授权时
RoleGranted(bytes32 role,address account,address sender)
角色取消授权时
RoleRevoked(bytes32 role,address account,address sender)
交易时
Transfer(address from,address to,uint256 tokenId)
取消暂停时
Unpaused(address account)
```

#### Function send
```
授权tokenId给to
approve(address to,uint256 tokenId)
生成mosaic token，调用者需要MINTER_ROLE权限
bornMosaic(string name,string defskill1,string defskill2,string defskill3,string defskill4,uint8 defstars,uint8 element,uint256 mosaicId,uint256 genes,address owner)
更新token genes时，调用者需要MINTER_ROLE权限
evolveMosaic(uint256 mosaicId_,uint256 newGenes_)
销毁token时，调用者需要MINTER_ROLE权限
retireMosaic(uint256 mosaicId_)
重设token genes时，调用者需要MINTER_ROLE权限
rebirthMosaic(uint256 mosaicId_,uint256 genes_)
角色回收
revokeRole(bytes32 role,address account)
角色授权
grantRole(bytes32 role,address account)
放弃合约所有权
renounceOwnership()
放弃某个角色
renounceRole(bytes32 role,address account)
token转让，调用者自己确认to地址能正常接收NFT，否则将丢失此NFT。注意：我们用这个方法
transferFrom(address from,address to,uint256 tokenId)
token转让，如果to是一个合约应该调用其onERC721Received方法, 并且检查其返回值，如果返回值不为bytes4(keccak256("onERC721Received(address,uint256,bytes)"))抛出异常。一个可接收NFT的合约必须实现ERC721TokenReceiver接口
safeTransferFrom(address from,address to,uint256 tokenId)
token转让，同上
safeTransferFrom(address from,address to,uint256 tokenId,bytes _data)
将当前合约调用者的token操作权限给operator
setApprovalForAll(address operator,bool approved)
设置token base URL， onlyOwner操作
setBaseURI(string baseURI_)
转让合约所有权
transferOwnership(address newOwner)
暂停token转让限制， onlyOwner操作
pause()
恢复token转让限制， onlyOwner操作
unpause()
```

#### Function query
```
它是固定值：0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6
MINTER_ROLE() returns (bytes32)
查看某个地址拥有token数量
balanceOf(address owner)  returns (uint256)
查看某个token授权给了谁
getApproved(uint256 tokenId) returns (address)
查看Mosaic token信息
getMosaic(uint256 mosaicId_) returns ({string name,string defskill1,string defskill2,string defskill3,string defskill4,uint8 defstars,uint8 element,uint256 id,uint256 genes,uint256 bornAt})
查看某个已授角色列表某下标位置的地址
getRoleMember(bytes32 role,uint256 index) returns (address)
查看某个已授角色的地址数量
getRoleMemberCount(bytes32 role) returns (uint256)
查看某个地址是否有某个角色
hasRole(bytes32 role,address account)  returns (bool)
查看owner名下的token所有权限是否给了operator
isApprovedForAll(address owner,address operator) returns (bool)
查看合约名称
name() returns (string)
查看合约所有者
owner() returns (address)
查看token所有者
ownerOf(uint256 tokenId) returns (address)
是否已暂停token转让交易
paused() returns (bool)
是否支持指定接口
supportsInterface(bytes4 interfaceId) returns (bool)
查看合约符号
symbol() returns (string)
查看指定位置下的token
tokenByIndex(uint256 index) returns (uint256)
查看指定所有者名下指定位置的token
tokenOfOwnerByIndex(address owner,uint256 index) returns (uint256)
查看token URI
tokenURI(uint256 tokenId) returns (string)
查看token总数
totalSupply() returns (uint256)

```

#### Operator角色说明，对应需求方法说明
```
 4.4 设定Operator的相关功能：（我方托管的账户为Operator权限）
 采用角色(MINTER_ROLE)，只有一个。进行授权控制

 4.4.1 setOperator：NFT合约的Owner将某个地址（或多个地址）设定为管理员Operator以便Operator可以执行铸造NFT等相关功能（用于我方后台托管账户用于执行盲盒铸造NFT等操作）， 
 对应方法为 grantRole  授权某个地址MINTER_ROLE

 4.4.2 isOperator：（通用）查询某个地址是否为Operator
 对应方法为 hasRole  查询某个地址是否有某个角色

 4.4.3 revokeOperator：（仅Owner）NFT合约的Owner将某个地址（或多个地址）移除Operator
对应方法为 revokeRole 移除某个角色

 4.4.4 getOperatorCount：（通用）查询Operator索引个数
 对应方法为getRoleMemberCount
 
 4.4.5 getOperatorbyIndex：（通用）按照某个索引查询Operator的地址
 对应方法为getRoleMember
 
 4.4.6 revokeOperatorbyIndex：（仅Owner）按照某个索引（或多个索引）移除Operator
 对应方法为 revokeRoleByIndex
 
 4.4.7 renounceOperator：（Operator）移除自身的Operator权限
对应方法为 renounceRole 放弃某个角色

```
