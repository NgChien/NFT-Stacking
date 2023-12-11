// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "../nft/NovaXNFT.sol";
import "../data/StructData.sol";
import "../oracle/Oracle.sol";

contract Maintenance is Ownable, ERC721Holder {
    address public nft;
    address public token;
    uint16 public maintenanceFee;
    address private oracleContract;
    address public saleWallet = 0x4832Ce5F72523632de172684Db63Ea05265Aef91;
    uint256 private timeToRepair;
    uint256 private timeCanRepair;
    bool reentrancyGuardForRepair = false;
    mapping(uint256 => bool) nftNeedRepair;
    mapping(uint256 => uint256) lastRepair;
    mapping(uint256 => StructData.ListMaintenance) listTimeNftMaintenance;

    event NftNeedRepair(uint256 nft, uint256 _time);
    event NftRepaired(uint256 nft, uint256 _time);
    constructor(address _nft) {
        nft = _nft;
        timeToRepair = 30;
        timeCanRepair = 7;
    }

    modifier validId(uint256 _nftId) {
        require(NovaXNFT(nft).ownerOf(_nftId) != address(0), "INVALID NFT ID");
        _;
    }

    function setSaleWalletAddress(address _saleAddress) external onlyOwner {
        require(_saleAddress != address(0), "MARKETPLACE: INVALID SALE ADDRESS");
        saleWallet = _saleAddress;
    }

    function setNftAddress(address _nftAddress) external onlyOwner {
        require(_nftAddress != address(0), "MAINTENANCE: INVALID NFT ADDRESS");
        nft = _nftAddress;
    }

    function setTokenAddress(address _tokenAddress) external onlyOwner {
        require(_tokenAddress != address(0), "MAINTENANCE: INVALID TOKEN ADDRESS");
        token = _tokenAddress;
    }

    function setOracleAddress(address _oracleAddress) external onlyOwner {
        require(_oracleAddress != address(0), "MARKETPLACE: INVALID ORACLE ADDRESS");
        oracleContract = _oracleAddress;
    }

    function setMaintenanceFee(uint16 _percent) external onlyOwner {
        require(_percent >= 0 && _percent <= 100, "MAINTENANCE: INVALID PERCENT FEE");
        maintenanceFee = _percent;
    }

    function getFeeMaintainNft(uint256 _nftId) public view validId(_nftId) returns (uint256) {
        if (maintenanceFee == 0 || oracleContract == address(0) || token == address(0)) {
            return 0;
        }
        uint256 nftValueInUsd = NovaXNFT(nft).getNftPriceUsd(_nftId);
        uint256 nftValueInToken = Oracle(oracleContract)
            .convertUsdBalanceDecimalToTokenDecimal(nftValueInUsd);
        uint256 feeToMaintain = nftValueInToken * (10 ** NovaXERC20(token).decimals()) * maintenanceFee / 100;
        return feeToMaintain;
    }

    function setDayNeedToRepair(uint256 _dayToNeedRepair) external onlyOwner {
        timeToRepair = _dayToNeedRepair;
    }

    function setTimeCanRepair(uint256 _dayCanRepair) external onlyOwner {
        timeCanRepair = _dayCanRepair;
    }

    function getDayNeedToRepair() external view returns (uint256) {
        return timeToRepair;
    }

    function getDayCanRepair() external view returns (uint256) {
        return timeCanRepair;
    }

    function isNeedRepair(uint256 _nftId) external view validId(_nftId) returns (bool)  {
        bool isRepair = nftNeedRepair[_nftId];
        if (isRepair) {
            return isRepair;
        }
        if (timeToRepair == 0) {
            return false;
        }
        uint256 timeNow = block.timestamp;
        uint256 timeNeedRepair = getTimeRepair(_nftId);
        if (timeNeedRepair == 0) {
            return false;
        }
        if (timeNeedRepair <= timeNow) {
            return true;
        } else {
            return false;
        }
    }

    function checkNftNeedRepair(uint256 _nftId) external validId(_nftId) returns (bool) {
        bool isRepair = nftNeedRepair[_nftId];
        if (isRepair) {
            return isRepair;
        }
        if (timeToRepair == 0) {
            return false;
        }
        uint256 timeNow = block.timestamp;
        uint256 timeNeedRepair = getTimeRepair(_nftId);
        if (timeNeedRepair == 0) {
            return false;
        }
        if (timeNeedRepair <= timeNow) {
            nftNeedRepair[_nftId] = true;
            (bool checkSaveTime, StructData.InfoMaintenanceNft memory item, ) = checkTimeInListMaintenance(timeNeedRepair, _nftId);
            if (!checkSaveTime) {
                item.startTimeRepair = timeNeedRepair;
                item.endTimeRepair = 0;
                listTimeNftMaintenance[_nftId].childList.push(item);
            }
            emit NftNeedRepair(_nftId, timeNeedRepair);
            return true;
        } else {
            nftNeedRepair[_nftId] = false;
            return false;
        }
    }

    function checkNftNextTimeRepair(uint256 _nftId) public view validId(_nftId) returns (uint256) {
        uint256 timeNeedRepair = getTimeRepair(_nftId);
        if (timeNeedRepair != 0) {
            timeNeedRepair = timeNeedRepair - timeCanRepair * 24 * 3600;
        }
        return timeNeedRepair;
    }

    function checkTimeInListMaintenance(uint256 _timeNeedRepair, uint256 _nftId) internal view returns (bool, StructData.InfoMaintenanceNft memory, uint) {
        StructData.InfoMaintenanceNft[] memory listMaintenance = listTimeNftMaintenance[_nftId].childList;
        bool checkSaveTime = false;
        uint idxMaintain = 0;
        StructData.InfoMaintenanceNft memory item;
        for (uint i = 0; i < listMaintenance.length; i++) {
            uint256 checkTime = listMaintenance[i].startTimeRepair;
            if (checkTime == _timeNeedRepair) {
                checkSaveTime = true;
                item = listMaintenance[i];
                idxMaintain = i;
                break;
            }
        }
        return (checkSaveTime, item, idxMaintain);
    }

    function getTimeRepair(uint256 _nftId) public view returns (uint256)  {
        uint256 lastTimeRepair = lastRepair[_nftId];
        if (lastTimeRepair == 0) {
            lastTimeRepair = NovaXNFT(nft).getBuyTime(_nftId); //buy time
        }
        if (lastTimeRepair == 0) {
            return 0;
        }
        uint256 timeNeedRepair = lastTimeRepair + timeToRepair *  3600 * 24;
        return timeNeedRepair;
    }

    function repairNft(uint256 _nftId) external validId(_nftId) {
        require(!reentrancyGuardForRepair, "MAINTENANCE: REENTRANCY DETECTED");
        reentrancyGuardForRepair = true;
        uint256 timeNeedRepair = getTimeRepair(_nftId);
        uint256 timeUserCanRepair = checkNftNextTimeRepair(_nftId);
        require(block.timestamp >= timeUserCanRepair, "MAINTENANCE: CAN NOT REPAIR NFT");
        uint256 feeNft = getFeeMaintainNft(_nftId);
        if (feeNft != 0 && token != address(0)) {
            require(
                NovaXERC20(token).balanceOf(msg.sender) >=
                feeNft,
                "MAINTENANCE: NOT ENOUGH BALANCE CURRENCY TO REPAIR NFTs"
            );
            require(
                NovaXERC20(token).allowance(msg.sender, address(this)) >=
                feeNft,
                "MAINTENANCE: MUST APPROVE FIRST"
            );
            require(
                NovaXERC20(token).transferFrom(
                    msg.sender,
                    saleWallet,
                    feeNft
                ),
                "MAINTENANCE: FAILED IN TRANSFER CURRENCY TO MAINTENANCE"
            );
        }
        nftNeedRepair[_nftId] = false;
        if (block.timestamp >= timeNeedRepair) {
            (bool checkSaveTime, StructData.InfoMaintenanceNft memory item, uint idxMaintain) = checkTimeInListMaintenance(timeNeedRepair, _nftId);
            if (checkSaveTime) {
                item.endTimeRepair = block.timestamp;
                listTimeNftMaintenance[_nftId].childList[idxMaintain] = item;
            } else {
                item.startTimeRepair = timeNeedRepair;
                item.endTimeRepair = block.timestamp;
                listTimeNftMaintenance[_nftId].childList.push(item);
            }
            lastRepair[_nftId] = block.timestamp;
            emit NftRepaired(_nftId, block.timestamp + timeToRepair * 3600 * 24);
        } else {
            lastRepair[_nftId] = timeNeedRepair;
            emit NftRepaired(_nftId, timeNeedRepair + timeToRepair * 3600 * 24);
        }
        reentrancyGuardForRepair = false;
    }

    function getTotalTimeRepair(uint256 _nftId) external view validId(_nftId) returns (uint256) {
        StructData.InfoMaintenanceNft[] memory listMaintenance = listTimeNftMaintenance[_nftId].childList;
        uint256 totalTime = 0;
        for (uint i = 0; i < listMaintenance.length; i++) {
            uint256 startTime = listMaintenance[i].startTimeRepair;
            uint256 endTime = listMaintenance[i].endTimeRepair;
            if (endTime == 0) {
                endTime = block.timestamp;
            }
            totalTime = totalTime + (endTime - startTime);
        }
        return totalTime;
    }

    function getTotalTimeStakeBroken(uint256 _nftId, uint256 stakeTime) external view validId(_nftId) returns (uint256) {
        StructData.InfoMaintenanceNft[] memory listMaintenance = listTimeNftMaintenance[_nftId].childList;
        uint256 totalTime = 0;
        for (uint i = 0; i < listMaintenance.length; i++) {
            uint256 endTime = listMaintenance[i].endTimeRepair;
            if (endTime == 0) {
                endTime = block.timestamp;
            }
            if (endTime > stakeTime) {
                uint256 startTime = listMaintenance[i].startTimeRepair;
                if (stakeTime < stakeTime) {
                    stakeTime = stakeTime;
                }
                totalTime = totalTime + (endTime - startTime);
            }
        }

        // total time không được claim
        uint256 lastTimeRepair = getTimeRepair(_nftId);
        if (lastTimeRepair < block.timestamp) {
            totalTime = totalTime + block.timestamp - lastTimeRepair;
        }

        return totalTime;
    }

    /**
    * @dev Recover lost bnb and send it to the contract owner
     */
    function recoverLostBNB() public onlyOwner {
        address payable recipient = payable(msg.sender);
        recipient.transfer(address(this).balance);
    }

    /**
        * @dev withdraw some token balance from contract to owner account
     */
    function withdrawTokenEmergency(address _token, uint256 _amount) public onlyOwner {
        require(_amount > 0, "INVALID AMOUNT");
        require(NovaXERC20(_token).transfer(msg.sender, _amount), "CANNOT WITHDRAW TOKEN");
    }
}
