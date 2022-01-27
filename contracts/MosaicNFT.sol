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

    event MosaicBorned(uint256 indexed _mosaicId, address indexed _owner, uint256 _genes);
    event MosaicRebirthed(uint256 indexed _mosaicId, uint256 _genes);
    event MosaicRetired(uint256 indexed _mosaicId);
    event MosaicEvolved(uint256 indexed _mosaicId, uint256 _oldGenes, uint256 _newGenes);

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

    function setBaseURI(string memory baseURI_) external onlyOwner {
        baseURI = baseURI_;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function pause() public whenNotPaused onlyOwner {
        _pause();
    }

    function unpause() public whenPaused onlyOwner {
        _unpause();
    }

    function getMosaic(uint256 _mosaicId) external view returns (Mosaic memory){
        return mosaics[_mosaicId];
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
        address owner) external onlyRole(MINTER_ROLE) {
        Mosaic memory mosaic = Mosaic(name, defskill1, defskill2, defskill3, defskill4, defstars, element, mosaicId, genes, block.timestamp);
        mosaics[mosaicId] = mosaic;
        _mint(owner, mosaicId);
        emit MosaicBorned(mosaicId, owner, genes);
    }

    //重生
    function rebirthMosaic(uint256 _mosaicId, uint256 _genes) external onlyRole(MINTER_ROLE) {
        require(mosaics[_mosaicId].bornAt != 0, "Rebirth: token nonexistent");

        Mosaic storage _mosaic = mosaics[_mosaicId];
        _mosaic.genes = _genes;
        _mosaic.bornAt = block.timestamp;
        emit MosaicRebirthed(_mosaicId, _genes);
    }

    //消毁
    function retireMosaic(uint256 _mosaicId) external onlyRole(MINTER_ROLE) {
        _burn(_mosaicId);
        delete(mosaics[_mosaicId]);

        emit MosaicRetired(_mosaicId);
    }

    //进化
    function evolveMosaic(uint256 _mosaicId, uint256 _newGenes) external onlyRole(MINTER_ROLE) {
        require(mosaics[_mosaicId].bornAt != 0, "Evolve: token nonexistent");

        uint256 _oldGenes = mosaics[_mosaicId].genes;
        mosaics[_mosaicId].genes = _newGenes;
        emit MosaicEvolved(_mosaicId, _oldGenes, _newGenes);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal whenNotPaused override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);

        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }
    }
}
