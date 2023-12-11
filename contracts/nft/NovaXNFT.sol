// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

contract NovaXNFT is ERC721, Ownable, Pausable, ERC721Burnable {
    uint256 public tokenCount;

    uint256 private lockDay;
    //staking address
    address private stakingContractAddress;
    //marketplace address
    address private marketplaceContractAddress;
    // Mapping from token ID to token URI
    mapping(uint256 => string) private tokenURIs;
    // Mapping from tier to price
    mapping(uint16 => uint256) public tierPrices;
    // Mapping from tier ID to apr percent
    mapping(uint16 => uint16) public aprPercentValues;
    // Mapping from token ID to tier
    mapping(uint256 => uint16) private tokenTiers;
    // Mapping from token ID to time lock transfer
    mapping(uint256 => uint256) private lockTimeTransfer;
    mapping(uint256 => uint256) private buyTime;
    // Mapping from token ID to equip pool
    mapping(uint256 => bool) private equipPool;

    constructor(
        string memory _name,
        string memory _symbol,
        address _manager
    ) ERC721(_name, _symbol) {
        marketplaceContractAddress = address(0);
        stakingContractAddress = address(0);
        lockDay = 365;
        transferOwnership(_manager);
        initTierPrices();
        initAprPercentValues();
    }

    modifier validId(uint256 _nftId) {
        require(ownerOf(_nftId) != address(0), "INVALID NFT ID");
        _;
    }

    function initTierPrices() public onlyOwner {
        tierPrices[1] = 30000;
        tierPrices[2] = 10000;
        tierPrices[3] = 5000;
        tierPrices[4] = 3000;
        tierPrices[5] = 1000;
        tierPrices[6] = 500;
        tierPrices[7] = 200;
    }

    function initAprPercentValues() public onlyOwner {
        aprPercentValues[7] = 60;
        aprPercentValues[6] = 66;
        aprPercentValues[5] = 72;
        aprPercentValues[4] = 78;
        aprPercentValues[3] = 84;
        aprPercentValues[2] = 90;
        aprPercentValues[1] = 96;
    }

    /**
        * @dev set staking contract address
     */
    function setStakingContractAddress(address _stakingAddress) external onlyOwner {
        require(_stakingAddress != address(0), "NFT: INVALID STAKING ADDRESS");
        stakingContractAddress = _stakingAddress;
    }


    function setMarketplaceContract(address _marketplaceAddress) external onlyOwner {
        require(_marketplaceAddress != address(0), "NFT: INVALID MARKETPLACE ADDRESS");
        marketplaceContractAddress = _marketplaceAddress;
    }

    function setTierPriceUsd(uint16 _tier, uint256 _price) external onlyOwner {
        tierPrices[_tier] = _price;
    }

    function setAprPercentValues(uint16 _tier, uint16 _percent) external onlyOwner {
        aprPercentValues[_tier] = _percent;
    }

    function setLockTransferDay(uint256 _lockDay) external onlyOwner {
        lockDay = _lockDay;
    }

    function setLockTimeTransfer(uint256 _nftId, uint256 timeLockNft) external {
        require(
            marketplaceContractAddress != address(0) && msg.sender == marketplaceContractAddress,
            "NFT: INVALID CALLER TO UPDATE LOCK TIME NFT DATA"
        );
        equipPool[_nftId] = true;
        lockTimeTransfer[_nftId] = timeLockNft;
        buyTime[_nftId] = timeLockNft;
    }

    function equipNFT(uint256 _nftId) external {
        address owner = super.ownerOf(_nftId);
        require(
            owner == msg.sender,
            "NFT: ONLY OWNER OF NFT CAN REMOVE NFT FROM EQUIP POOL"
        );
        bool isEquipped = equipPool[_nftId];
        uint256 buyTimeNft = buyTime[_nftId];
        if (!isEquipped) {
            equipPool[_nftId] = true;
            if (buyTimeNft == 0) {
                buyTime[_nftId] = block.timestamp;
            }
        }
    }

    function getIsEquipNft(uint256 _nftId) external view validId(_nftId) returns (bool) {
        bool isEquipped = equipPool[_nftId];
        return isEquipped;
    }

    function removeNftFromPool(uint256 _nftId) external {
        address owner = super.ownerOf(_nftId);
        require(
            owner == msg.sender,
            "NFT: ONLY OWNER OF NFT CAN REMOVE NFT FROM EQUIP POOL"
        );
        uint256 timeTransfer = lockTimeTransfer[_nftId];
        uint256 lockTimeDay = timeTransfer + 3600 * 24 * lockDay;
        require(
            timeTransfer == 0 || (timeTransfer != 0 && block.timestamp >= lockTimeDay),
            "NFT: CANNOT REMOVE NFT FROM EQUIP POOL"
        );
        bool isEquipped = equipPool[_nftId];
        if (isEquipped) {
            equipPool[_nftId] = false;
        }
    }

    function setEquipNftByAdmin(uint256 _nftId, bool _isEquip) external onlyOwner {
        equipPool[_nftId] = _isEquip;
    }

    function setLockTimeNftByAdmin(uint256 _nftId, uint256 timeLockNft) external onlyOwner {
        lockTimeTransfer[_nftId] = timeLockNft;
        buyTime[_nftId] = timeLockNft;
    }

    function getBuyTime(uint256 _nftId) external view validId(_nftId) returns(uint256) {
        return buyTime[_nftId];
    }

    function getLockTimeTransfer(uint256 _nftId) external view validId(_nftId) returns(uint256) {
        return lockTimeTransfer[_nftId];
    }

    //for external call
    function getNftPriceUsd(uint256 _nftId) external view validId(_nftId) returns (uint256) {
        uint16 nftTier = tokenTiers[_nftId];
        return tierPrices[nftTier];
    }

    function getNftAprPercentValues(uint256 _nftId) external view validId(_nftId) returns (uint16) {
        uint16 nftTier = tokenTiers[_nftId];
        return aprPercentValues[nftTier];
    }

    //for external call
    function getNftTier(uint256 _nftId) external view validId(_nftId) returns (uint16) {
        return tokenTiers[_nftId];
    }

    function setNftTier(uint256 _nftId, uint16 _tier) public onlyOwner {
        tokenTiers[_nftId] = _tier;
    }

    function tokenURI(uint256 _nftId) public view virtual override returns (string memory) {
        require(ownerOf(_nftId) != address(0), "NFT ID NOT EXIST");
        return tokenURIs[_nftId];
    }

    function setTokenURI(uint256 _nftId, string memory _tokenURI) public onlyOwner {
        require(ownerOf(_nftId) != address(0), "NFT ID NOT EXIST");
        require(bytes(_tokenURI).length > 0, "TOKEN URI MUST NOT NULL");
        tokenURIs[_nftId] = _tokenURI;
    }

    function mint(string memory _tokenURI, uint8 _tier) public onlyOwner {
        require(bytes(_tokenURI).length > 0, "TOKEN URI MUST NOT NULL");
        tokenCount++;
        tokenURIs[tokenCount] = _tokenURI;
        tokenTiers[tokenCount] = _tier;
        _safeMint(msg.sender, tokenCount);
    }

    function batchMint(string[] memory _tokenURI, uint8 _tier) public onlyOwner {
        require(_tokenURI.length > 0, "SIZE LIST URI MUST NOT BE ZERO");
        uint256 index;
        for (index = 0; index < _tokenURI.length; ++index) {
            mint(_tokenURI[index], _tier);
        }
    }

    function mintTo(string memory _tokenURI, uint8 _tier, address _to) public onlyOwner {
        require(_to != address(0), "NOT ACCEPT ZERO ADDRESS");
        require(bytes(_tokenURI).length > 0, "TOKEN URI MUST NOT NULL");
        tokenCount++;
        tokenURIs[tokenCount] = _tokenURI;
        tokenTiers[tokenCount] = _tier;
        _safeMint(_to, tokenCount);
    }

    function batchMintTo(string[] memory _tokenURI, uint8 _tier, address _to) public onlyOwner {
        require(_tokenURI.length > 0, "SIZE LIST URI MUST NOT BE ZERO");
        uint256 index;
        for (index = 0; index < _tokenURI.length; ++index) {
            mintTo(_tokenURI[index], _tier, _to);
        }
    }

    function totalSupply() public view virtual returns (uint256) {
        return tokenCount;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public override {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    function supportsInterface(bytes4 interfaceID) public pure override returns (bool) {
        return interfaceID == 0x80ac58cd || interfaceID == 0x5b5e139f;
    }

    function _beforeTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize)
    internal virtual override
    {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
        bool isEquipped = equipPool[firstTokenId];
        uint256 timeTransfer = lockTimeTransfer[firstTokenId];
        uint256 lockTimeDay = timeTransfer + 3600 * 24 * lockDay;
        require(
            !isEquipped || (to == stakingContractAddress),
            "NFT: CANNOT TRANSFER TOKEN"
        );
        require(
            timeTransfer == 0 || (timeTransfer != 0 && block.timestamp >= lockTimeDay) || (to == stakingContractAddress),
            "NFT: CANNOT TRANSFER TOKEN"
        );
    }

    function _afterTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize) internal virtual override {
        super._afterTokenTransfer(from, to, firstTokenId, batchSize);
        bool isEquipped = equipPool[firstTokenId];
        if (isEquipped && to == stakingContractAddress) {
            equipPool[firstTokenId] = false;
        }
    }
}
