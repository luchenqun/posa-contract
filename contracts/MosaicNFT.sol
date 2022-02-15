// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "./common/AccessControl.sol";
import "./utils/Counters.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract MosaicNFT is ERC721, ERC721Enumerable, Pausable, AccessControl {
    using Strings for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    mapping(uint256 => string) private _tokenURIs;
    mapping(uint256 => bool) private _frozenTokens;
    mapping(address => bool) private _frozenAddrs;
    // List of addresses that have a number of reserved tokens for presale
    mapping(address => uint16) public presaleAddresses;
    mapping(uint256 => Mosaic) private mosaics;
    mapping(string => uint256) private orderIds;
    PayTokenPrice[] public payTokenPrices;
    Payee[] public payees; // 收款人百分比
    string private baseURI;
    // Starting and stopping sale and presale
    bool public presaleActive;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    struct Mosaic {
        string name;
        string defskill1;
        string defskill2;
        string defskill3;
        string defskill4;
        uint8 defstars;
        uint8 element;
        uint256 id;
        uint256 genes;
        uint256 bornAt;
    }
    // 收款对象结构体
    struct Payee {
        address payable beneficiary; // 收款人
        uint16 percentage; // 收款百分比
    }

    // 预售支付币种及价格
    struct PayTokenPrice {
        address token; // 预售支付币种
        uint256 price; // 预售支付价格
    }

    event MosaicBorned(uint256 indexed mosaicId_, address indexed owner_, uint256 genes_);
    event MosaicRebirthed(uint256 indexed mosaicId_, uint256 genes_);
    event MosaicRetired(uint256 indexed mosaicId_);
    event MosaicEvolved(uint256 indexed mosaicId_, uint256 oldGenes_, uint256 newGenes_);
    event MosaicFreeze(uint256 indexed mosaicId_);
    event MosaicUnFreeze(uint256 indexed mosaicId_);
    event MosaicOwnerFreeze(address indexed owner_);
    event MosaicOwnerUnFreeze(address indexed owner_);
    /**
     * @dev Throws if called by any account other than the owner or special role.
     */
    modifier onlyOwnerOrRole(bytes32 role) {
        if(owner() != _msgSender()){
            _checkRole(role, _msgSender());
        }
        _;
    }
    /**
     * @dev Modifier to make a function callable only when the mosaic token is not frozen.
     * Requirements: The mosaic token must not be frozen.
     */
    modifier whenMosaicNotFrozen(uint256 tokenId) {
        require(!mosaicFrozen(tokenId), "Mosaic freezable: frozen");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the mosaic token is frozen.
     * Requirements: The mosaic token must be frozen.
     */
    modifier whenMosaicFrozen(uint256 tokenId) {
        require(mosaicFrozen(tokenId), "Mosaic freezable: not frozen");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the mosaic owner is not frozen.
     * Requirements: The mosaic owner must not be frozen.
     */
    modifier whenAddrNotFrozen(address addr) {
        require(!addrFrozen(addr), "Mosaic's owner freezable: frozen");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the mosaic owner is frozen.
     * Requirements: The mosaic owner must be frozen.
     */
    modifier whenAddrFrozen(address addr) {
        require(addrFrozen(addr), "Mosaic's owner freezable: not frozen");
        _;
    }

    modifier whenPresaleActive(){
        require(presaleActive, "Presale not activated");
        _;
    }

    constructor(string memory name_, string memory symbol_, string memory baseURI_) ERC721(name_, symbol_) {
        baseURI = baseURI_;
        _tokenIds.reset();
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory){
        string memory _tokenURI = _tokenURIs[tokenId];
        if (bytes(_tokenURI).length > 0) {
            return _tokenURI;
        }
        Mosaic memory _mosaic = mosaics[tokenId];

        return string(abi.encodePacked(baseURI, tokenId.toString(), "/" , _mosaic.genes.toHexString(), ".json"));
    }

    function setBaseURI(string memory baseURI_) external onlyOwnerOrRole(MINTER_ROLE) {
        baseURI = baseURI_;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function pause() public whenNotPaused onlyOwnerOrRole(MINTER_ROLE) {
        _pause();
    }

    function unpause() public whenPaused onlyOwnerOrRole(MINTER_ROLE) {
        _unpause();
    }

    // 根据mosaicId查询NFT卡片
    function getMosaic(uint256 mosaicId_) external view returns (Mosaic memory){
        return mosaics[mosaicId_];
    }

    // 根据订单ID查询tokenId
    function getTokenId(string memory orderId_) external view returns (uint256){
        require(orderIds[orderId_] != 0,"order id not exists");
        uint256 tokenId = orderIds[orderId_];
        return tokenId;
    }

    //新生mosaic
    function bornMosaic(
        string memory orderId,
        string memory name,
        string memory defskill1,
        string memory defskill2,
        string memory defskill3,
        string memory defskill4,
        uint8 defstars,
        uint8 element,
        uint256 genes,
        address owner) external onlyOwnerOrRole(MINTER_ROLE) {
        _bornMosaic(orderId,name,defskill1,defskill2,defskill3,defskill4,defstars,element,genes,owner);
    }

    //新生mosaic
    function _bornMosaic(
        string memory orderId,
        string memory name,
        string memory defskill1,
        string memory defskill2,
        string memory defskill3,
        string memory defskill4,
        uint8 defstars,
        uint8 element,
        uint256 genes,
        address owner) private{
        uint256 mosaicId = _tokenIds.incrementAndGet();
        console.log("mosaicId",mosaicId);
        Mosaic memory mosaic_ = Mosaic(name, defskill1, defskill2, defskill3, defskill4, defstars, element, mosaicId, genes, block.timestamp);
        mosaics[mosaicId] = mosaic_;
        if(bytes(orderId).length > 0){
            require(orderIds[orderId] == 0,"order id already exists");
            orderIds[orderId] = mosaicId;
        }
        _mint(owner, mosaicId);
        emit MosaicBorned(mosaicId, owner, genes);
    }

    //重生
    function rebirthMosaic(uint256 mosaicId_, uint256 genes_) external onlyOwnerOrRole(MINTER_ROLE) {
        require(mosaics[mosaicId_].bornAt != 0, "Rebirth: token nonexistent");

        Mosaic storage _mosaic = mosaics[mosaicId_];
        _mosaic.genes = genes_;
        _mosaic.bornAt = block.timestamp;
        emit MosaicRebirthed(mosaicId_, genes_);
    }

    //重生带订单ID
    function rebirthMosaicByOrderId(uint256 mosaicId_, uint256 genes_, string memory orderId_) external onlyOwnerOrRole(MINTER_ROLE) {
        require(mosaics[mosaicId_].bornAt != 0, "Rebirth: token nonexistent");
        require(orderIds[orderId_] == 0,"order id already exists");
        Mosaic storage _mosaic = mosaics[mosaicId_];
        _mosaic.genes = genes_;
        _mosaic.bornAt = block.timestamp;
        emit MosaicRebirthed(mosaicId_, genes_);
    }

    //消毁
    function retireMosaic(uint256 mosaicId_) external onlyOwnerOrRole(MINTER_ROLE) {
        _burn(mosaicId_);
        delete mosaics[mosaicId_];
        emit MosaicRetired(mosaicId_);
    }

    //消毁带订单ID
    function retireMosaicByOrderId(uint256 mosaicId_,string memory orderId_) external onlyOwnerOrRole(MINTER_ROLE) {
        require(orderIds[orderId_] == mosaicId_,"order id already exists");
        _burn(mosaicId_);
        delete mosaics[mosaicId_];
        delete orderIds[orderId_];
        emit MosaicRetired(mosaicId_);
    }

    //进化
    function evolveMosaic(uint256 mosaicId_, uint256 newGenes_) external onlyOwnerOrRole(MINTER_ROLE) {
        require(mosaics[mosaicId_].bornAt != 0, "Evolve: token nonexistent");

        uint256 oldGenes_ = mosaics[mosaicId_].genes;
        mosaics[mosaicId_].genes = newGenes_;
        emit MosaicEvolved(mosaicId_, oldGenes_, newGenes_);
    }

    //进化带订单ID
    function evolveMosaicByOrderId(uint256 mosaicId_, uint256 newGenes_, string memory orderId_) external onlyOwnerOrRole(MINTER_ROLE) {
        require(mosaics[mosaicId_].bornAt != 0, "Evolve: token nonexistent");
        require(orderIds[orderId_] == 0,"order id already exists");
        uint256 oldGenes_ = mosaics[mosaicId_].genes;
        mosaics[mosaicId_].genes = newGenes_;
        emit MosaicEvolved(mosaicId_, oldGenes_, newGenes_);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
    internal whenNotPaused whenAddrNotFrozen(from) whenAddrNotFrozen(to) whenMosaicNotFrozen(tokenId)
    override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);

        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }
    }

    //通过tokenId冻结某个NFT，使之不能转账交易
    function freezeMosaic(uint256 tokenId) public whenMosaicNotFrozen(tokenId) onlyOwnerOrRole(MINTER_ROLE) {
        _frozenTokens[tokenId] = true;
        emit MosaicFreeze(tokenId);
    }

    //通过tokenId取消冻结某个NFT，使之恢复转账交易
    function unfreezeMosaic(uint256 tokenId) public whenMosaicFrozen(tokenId) onlyOwnerOrRole(MINTER_ROLE) {
        delete _frozenTokens[tokenId];
        emit MosaicUnFreeze(tokenId);
    }

    //通过tokenId查询该NFT是否已经被冻结
    function mosaicFrozen(uint256 tokenId) public view returns (bool) {
        return _frozenTokens[tokenId];
    }

    //冻结某个Address上所有该合约的NFT冻结，使之不能转账交易，既不能转入也不能转出该合约的NFT
    function freezeMosaicByAddr(address addr) public whenAddrNotFrozen(addr) onlyOwnerOrRole(MINTER_ROLE) {
        _frozenAddrs[addr] = true;
        emit MosaicOwnerFreeze(addr);
    }

    //取消冻结某个账户地址上所有该合约的NFT冻结，使之恢复转账交易
    function unfreezeMosaicByAddr(address addr) public whenAddrFrozen(addr) onlyOwnerOrRole(MINTER_ROLE) {
        delete  _frozenAddrs[addr];
        emit MosaicOwnerUnFreeze(addr);
    }

    //通过Address查询该地址是否已经被冻结了该合约的NFT转账交易
    function addrFrozen(address addr) public view returns (bool) {
        return _frozenAddrs[addr];
    }

    //开启或者关闭预售
    function setPresaleActive(bool active) public onlyOwnerOrRole(MINTER_ROLE){
        presaleActive = active;
    }

    //批量设置可铸造地址和数量
    function setPresaleReservedAddresses(address[] memory addresses, uint16[] memory amounts) public onlyOwnerOrRole(MINTER_ROLE) {
        require(addresses.length == amounts.length,"wrong number of parameters");
        uint16 length = uint16(addresses.length);
        for(uint16 i; i < length; i++){
            presaleAddresses[addresses[i]] = amounts[i];
        }
    }
    //预售支付的币种和对应的价格
    function setPayTokenAndPrice(address[] memory tokens,uint256[] memory prices) public onlyOwnerOrRole(MINTER_ROLE) {
        require(tokens.length == prices.length,"wrong number of parameters");
        delete payTokenPrices;
        uint16 length = uint16(tokens.length);
        for(uint16 i; i < length; i++){
            payTokenPrices.push(PayTokenPrice(tokens[i], prices[i]));
        }
    }

    //查询 payTokenAndPrice的索引个数
    function payTokenAndPriceCount() public view returns (uint256){
        return payTokenPrices.length;
    }

    //按照某个索引查询预售支付的币种和对应的价格
    function payTokenAndPriceByIndex(uint16 index) public view returns (PayTokenPrice memory){
        return payTokenPrices[index];
    }
    //根据币种查价格
    function getPriceByPayToken(address payToken) public view returns (uint256){
        uint256 price;
        for(uint16 i = 0; i < payTokenPrices.length; i++){
            if(payTokenPrices[i].token == payToken ){
                price = payTokenPrices[i].price;
                break;
            }
        }
        return price;
    }

    //设置预售订单的分成地址和比例
    function setProfitSharing(address[] memory beneficiaries,uint16[] memory percentages) public onlyOwnerOrRole(MINTER_ROLE) {
        require(beneficiaries.length == percentages.length, "beneficiaries.length should equal percentages.length");
        uint256 total = 0;
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            require(percentages[i] <= 100, "percentages must less than 100");
            total += percentages[i];
        }
        require(total == 100, "percentages sum must 100");
        delete payees;
        for(uint256 i = 0; i < beneficiaries.length; i++) {
            payees.push(Payee(payable(beneficiaries[i]), percentages[i]));
        }
    }
    //根据分成地址获取分成比例
    function getProfitSharing(address beneficiary) public view returns (uint16){
        uint16 percentage;
        for(uint16 i = 0;i < payees.length; i++){
            if(payees[i].beneficiary == beneficiary){
                percentage = payees[i].percentage;
                break;
            }
        }
        return percentage;
    }

    //由用户发起自己铸造已预订的预售订单所涉及的NFT
    function bornPresaleMosaicByOrderId(
        string memory orderId,
        string memory name,
        string memory defskill1,
        string memory defskill2,
        string memory defskill3,
        string memory defskill4,
        uint8 defstars,
        uint8 element,
        uint256 genes,
        address payToken
    ) public whenPresaleActive{
        uint16 quantity = presaleAddresses[_msgSender()];
        require(quantity > 0,"presale quantity must be greater than 0");
        uint256 price = getPriceByPayToken(payToken);
        require(price > 0,"presale price must be greater than 0");
        require(payees.length > 0,"profit sharing not set");
        //console.log("quantity:",quantity);
        //console.log("price:",price);

        uint256 curSum = 0;
        //利润分摊
        for (uint256 i = 0; i < payees.length; i++) {
            uint256 curAmount = (i == payees.length - 1) ? (price - curSum) : ((price * payees[i].percentage) / 100);
            curSum += curAmount;
             //console.log("curAmount:",curAmount);
            if(payToken == address(0)){
                payees[i].beneficiary.transfer(curAmount);
            }else{
                IERC20(payToken).transferFrom(_msgSender(),payees[i].beneficiary,curAmount);
            }
        }
        //铸造token
        _bornMosaic(orderId,name,defskill1,defskill2,defskill3,defskill4,defstars,element,genes,_msgSender());
        //可预售数量-1
        presaleAddresses[_msgSender()] -= 1;
    }

}
