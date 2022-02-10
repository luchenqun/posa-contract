// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NFTSale is Ownable, Pausable {

    address [] public priceTokens;   //交易币种
    mapping(address => bool) private _blacklist; //黑名单
    uint16 public fee; //手续费率
    Payee[] public payees; // 收款人百分比
    mapping(bytes32 => Sale) private _saleRecordDetail; //keccak256(abi.encodePacked(nftAddress,tokenId))与sale明细的映射
    mapping(address => bytes32[]) private _saleRecords; //sellerAddress与keccak256(abi.encodePacked(nftAddress,tokenId))的映射

    // 收款对象结构体
    struct Payee {
        address payable beneficiary; // 收款人
        uint16 percentage; // 收款百分比
    }

    //订单结构体
    struct Sale {
        string orderId;
        address sellerAddress;
        address nftAddress;
        address priceToken;
        uint256 tokenId;
        uint256 tokenPrice;
        uint256 updateAt;
    }

    //事件
    event CreateSale(address indexed sellerAddress, address indexed nftAddress,uint256 indexed tokenId);
    event UpdateSale(address indexed sellerAddress, address indexed nftAddress,uint256 indexed tokenId);
    event DeleteSale(address indexed sellerAddress, address indexed nftAddress,uint256 indexed tokenId);
    event DeleteAllSale(address indexed sellerAddress);

    /**
     * Verify whether the specified price token is met
     */
    modifier explicitPriceToken(address priceToken) {
        require(priceTokens.length > 0, "price tokens must be specified");
        bool flag;
        for(uint256 i = 0;i < priceTokens.length; i++){
            if(priceTokens[i] == priceToken){
                flag = true;
                break;
            }
        }
        require(flag, "price token not explicitly");
        _;
    }

    /**
     * Check whether the range of fee ratio is correct
     */
    modifier checkFee(uint16 fee_) {
        require(fee_ > 0,"fee ratio must be greater than 0");
        require(fee_ < 10000,"fee ratio must be less than 10000");
        _;
    }

    /**
     * Check whether the transaction address is in the blacklist
     */
    modifier checkBlacklist(address addr){
        require(!isInBlackList(addr),"operation is not allowed in the blacklist");
        _;
    }

    /**
     * Verify whether it is NFT owner
     */
    modifier explicitNFTOwner(address nftOwner, address nftAddress, uint256 tokenId){
        address nftOwner_ = IERC721(nftAddress).ownerOf(tokenId);
        require(nftOwner_ == nftOwner, "not NFT owner");
        _;
    }

    constructor(uint16 fee_, address[] memory priceTokens_, address[] memory beneficiaries, uint16[] memory percentages) checkFee(fee_){
        fee = fee_;
        priceTokens = priceTokens_;
        setFeeSharing(beneficiaries,percentages);
    }

    function setFee(uint16 fee_) public onlyOwner checkFee(fee_){
        fee = fee_;
    }

    function setFeeSharing(address[] memory beneficiaries,uint16[] memory percentages) public onlyOwner {
        require(beneficiaries.length == percentages.length, "SetFeeSharing: beneficiaries.length should equal percentages.length");
        uint256 total = 0;
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            require(percentages[i] <= 100, "SetFeeSharing: percentages must less than 100");
            total += percentages[i];
        }
        require(total == 100, "SetFeeSharing: percentages sum must 100");
        delete payees;
        for(uint256 i = 0; i < beneficiaries.length; i++) {
            payees.push(Payee(payable(beneficiaries[i]), percentages[i]));
        }
    }

    function getFeeSharing(address beneficiary) public view returns (uint32){
        uint32 percentage;
        for(uint256 i = 0;i < payees.length; i++){
            if(payees[i].beneficiary == beneficiary){
                percentage = payees[i].percentage;
                break;
            }
        }
        return percentage;
    }


    function pause() public whenNotPaused onlyOwner {
        _pause();
    }

    function unpause() public whenPaused onlyOwner {
        _unpause();
    }

    function addBlackList(address addr) public onlyOwner{
        _blacklist[addr] = true;
    }
    function removeBlackList(address addr) public onlyOwner{
        delete _blacklist[addr];
    }
    function isInBlackList(address addr) public view returns (bool){
        return _blacklist[addr];
    }

    function forceCancel(address sellerAddress,address nftAddress,uint256 tokenId) public onlyOwner{
        _deleteSale(sellerAddress,nftAddress,tokenId);
    }

    function forceCancelAll(address sellerAddress) public onlyOwner{
        _deleteAllSale(sellerAddress);
    }

    function setPriceToken(address[] memory priceTokens_) public onlyOwner{
        priceTokens = priceTokens_;
    }

/*    function withdraw20(address to) public onlyOwner{

    }
    function withdraw721(address to) public onlyOwner{

    }
    function withdraw1155(address to) public onlyOwner{

    }*/

    function createSale(string memory orderId,address nftAddress,address priceToken,uint256 tokenId,uint256 tokenPrice)
    public whenNotPaused checkBlacklist(_msgSender()) explicitNFTOwner(_msgSender(),nftAddress,tokenId) explicitPriceToken(priceToken){
        address sellerAddress = _msgSender();
        require(!isSale(nftAddress,tokenId), "CreateSale: existing sale record");
        bytes32 recordHash = _saleRecordHash(nftAddress,tokenId);
        _saleRecords[sellerAddress].push(recordHash);
        _saleRecordDetail[recordHash] = Sale(orderId, sellerAddress,nftAddress,priceToken,tokenId,tokenPrice,block.timestamp);
        emit CreateSale(sellerAddress,nftAddress,tokenId);
    }

    function updateSale(address nftAddress,address priceToken,uint256 tokenId,uint256 tokenPrice)
    public whenNotPaused checkBlacklist(_msgSender()) explicitNFTOwner(_msgSender(),nftAddress,tokenId) explicitPriceToken(priceToken){
        Sale storage sale = _saleRecordDetail[_saleRecordHash(nftAddress,tokenId)];
        require(sale.sellerAddress != address(0), "UpdateSale: not existing nft sale record");
        sale.priceToken = priceToken;
        sale.tokenPrice = tokenPrice;
        sale.updateAt = block.timestamp;
        emit UpdateSale(sale.sellerAddress,nftAddress,tokenId);
    }

    function getSale(address nftAddress,uint256 tokenId) public view returns (Sale memory){
        return _saleRecordDetail[_saleRecordHash(nftAddress,tokenId)];
    }
    function isSale(address nftAddress,uint256 tokenId) public view returns (bool){
        return getSale(nftAddress,tokenId).sellerAddress != address(0);
    }
    function isSeller(address sellerAddress,address nftAddress,uint256 tokenId) public view returns (bool){
        return getSale(nftAddress,tokenId).sellerAddress == sellerAddress;
    }
    function getPriceTokenAndPrice(address nftAddress,uint256 tokenId) public view returns (address priceToken, uint256 tokenPrice){
        Sale memory sale = getSale(nftAddress,tokenId);
        return (sale.priceToken, sale.tokenPrice);
    }

    function cancelSale(address nftAddress,uint256 tokenId) public{
        require(isSale(nftAddress,tokenId), "CancelSale: not existing sale record");
        _deleteSale(_msgSender(),nftAddress,tokenId);
    }

    function cancelAllSale() public{
        _deleteAllSale(_msgSender());
    }

    function _deleteSale(address sellerAddress,address nftAddress,uint256 tokenId) private {
        bytes32 recordHash = _saleRecordHash(nftAddress,tokenId);
        delete _saleRecordDetail[recordHash];

        bytes32[] storage recordHashes = _saleRecords[sellerAddress];
        bool flag;
        for(uint256 i = 0; i < recordHashes.length; i++){
            if(recordHashes[i] == recordHash){
                flag = true;
            }
            if(flag && i < recordHashes.length-1){
                recordHashes[i] = recordHashes[i+1];
            }
        }
        if(flag){
            delete recordHashes[recordHashes.length-1];
        }
        emit DeleteSale(sellerAddress,nftAddress,tokenId);
    }

    function _deleteAllSale(address sellerAddress) private {
        bytes32[] memory recordHashes = _saleRecords[sellerAddress];
        for(uint256 i = 0; i < recordHashes.length; i++){
            delete _saleRecordDetail[recordHashes[i]];
        }
        delete _saleRecords[sellerAddress];
        emit DeleteAllSale(sellerAddress);
    }

    function _saleRecordHash(address nftAddress, uint256 tokenId) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(nftAddress,tokenId));
    }

    function bidSale(address payable sellerAddress,address nftAddress,uint256 tokenId)
    public whenNotPaused checkBlacklist(_msgSender()) explicitNFTOwner(sellerAddress,nftAddress,tokenId) {
        require(isSale(nftAddress,tokenId), "BidSale: not existing sale record");
        Sale memory sale = getSale(nftAddress,tokenId);
        //转token
        IERC721(nftAddress).transferFrom(sellerAddress,msg.sender, tokenId);
        //删除sale记录
        _deleteSale(sellerAddress,nftAddress,tokenId);
        //卖家实收金额
        uint256 actualAmount = sale.tokenPrice * (10000 - fee) / 10000;
        //总的手续费
        uint256 feeAmount = sale.tokenPrice - actualAmount;
        //原生币
        if(sale.priceToken == address(0)){
            payable(sellerAddress).transfer(actualAmount);
        }else{
        //合约币
            IERC20(sale.priceToken).transfer(sellerAddress, actualAmount);
        }
        uint256 curSum = 0;
        //手续费分摊
        for (uint256 i = 0; i < payees.length; i++) {
            uint256 curAmount = (i == payees.length - 1) ? (feeAmount - curSum) : ((feeAmount * payees[i].percentage) / 100);
            curSum += curAmount;
            if(sale.priceToken == address(0)){
                payees[i].beneficiary.transfer(curAmount);
            }else{
                IERC20(sale.priceToken).transfer(payees[i].beneficiary,curAmount);
            }
        }

    }
}
