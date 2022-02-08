// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "./common/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract MosaicNFT is ERC721, ERC721Enumerable, Pausable, AccessControl {
    using Strings for uint256;

    mapping(uint256 => string) private _tokenURIs;
    mapping(uint256 => bool) private _frozenTokens;
    mapping(address => bool) private _frozenAddrs;
    string private baseURI;

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
    mapping(uint256 => Mosaic) private mosaics;

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

    constructor(string memory name_, string memory symbol_, string memory baseURI_) ERC721(name_, symbol_) {
        baseURI = baseURI_;
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

    function getMosaic(uint256 mosaicId_) external view returns (Mosaic memory){
        return mosaics[mosaicId_];
    }

    //新生mosaic
    function bornMosaic(
        string memory name,
        string memory defskill1,
        string memory defskill2,
        string memory defskill3,
        string memory defskill4,
        uint8 defstars,
        uint8 element,
        uint256 mosaicId,
        uint256 genes,
        address owner) external onlyOwnerOrRole(MINTER_ROLE) {
        Mosaic memory mosaic_ = Mosaic(name, defskill1, defskill2, defskill3, defskill4, defstars, element, mosaicId, genes, block.timestamp);
        mosaics[mosaicId] = mosaic_;
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

    //消毁
    function retireMosaic(uint256 mosaicId_) external onlyOwnerOrRole(MINTER_ROLE) {
        _burn(mosaicId_);
        delete(mosaics[mosaicId_]);

        emit MosaicRetired(mosaicId_);
    }

    //进化
    function evolveMosaic(uint256 mosaicId_, uint256 newGenes_) external onlyOwnerOrRole(MINTER_ROLE) {
        require(mosaics[mosaicId_].bornAt != 0, "Evolve: token nonexistent");

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
}
