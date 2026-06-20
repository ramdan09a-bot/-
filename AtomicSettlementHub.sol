// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AtomicSettlementHub
 * @notice عقد تسوية ذرية آمن (Atomic Settlement Contract)
 * يوفر منصة آمنة للمعاملات بين المشترين والبائعين باستخدام العقود الذكية
 * 
 * المميزات الأمنية:
 * - استخدام SafeERC20 للتعامل الآمن مع الرموز
 * - استخدام ReentrancyGuard لمنع هجمات إعادة الدخول
 * - تطبيق نمط Checks-Effects-Interactions
 * - التحقق من الأمان على جميع العمليات
 */

interface IERC20Extended is IERC20 {
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
}

contract AtomicSettlementHub is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // ============ البنى الهيكلية (Data Structures) ============
    
    struct Deal {
        address buyer;
        address seller;
        uint256 price;
        uint256 tokenAmount;
        bool isSettled;
        bool isCancelled;
        uint256 createdAt;
        uint256 settledAt;
        string dealMetadata; // وصف التعامل
    }

    struct UserProfile {
        uint256 totalDeals;
        uint256 successfulDeals;
        uint256 totalVolume;
        uint256 reputation; // نقاط السمعة
        bool isActive;
    }

    // ============ المتغيرات الحالة (State Variables) ============
    
    mapping(bytes32 => Deal) public deals;
    mapping(address => UserProfile) public userProfiles;
    mapping(address => bytes32[]) public userDealHistory;
    
    IERC20 public immutable token;
    
    uint256 public dealCounter;
    uint256 public settlementFeePercentage = 25; // 0.25%
    address public feeCollector;
    
    bool public isContractActive = true;
    
    // ============ الأحداث (Events) ============
    
    event DealCreated(
        indexed bytes32 dealId,
        indexed address buyer,
        indexed address seller,
        uint256 price,
        uint256 tokenAmount,
        uint256 timestamp
    );
    
    event DealSettled(
        indexed bytes32 dealId,
        indexed address buyer,
        indexed address seller,
        uint256 price,
        uint256 settledAt
    );
    
    event DealCancelled(
        indexed bytes32 dealId,
        address indexed initiator,
        string reason,
        uint256 timestamp
    );
    
    event EmergencyWithdraw(
        address indexed to,
        uint256 amount,
        uint256 timestamp
    );
    
    event FeeCollected(
        uint256 amount,
        uint256 timestamp
    );
    
    event ReputationUpdated(
        address indexed user,
        uint256 newReputation,
        bool isIncrease
    );

    // ============ المعدلات (Modifiers) ============
    
    modifier onlyActive() {
        require(isContractActive, "العقد غير نشط حالياً");
        _;
    }
    
    modifier validAddress(address _addr) {
        require(_addr != address(0), "عنوان غير صحيح");
        _;
    }
    
    modifier validDealId(bytes32 _dealId) {
        require(deals[_dealId].createdAt > 0, "التعامل غير موجود");
        _;
    }

    // ============ الدالات البناء والتهيئة (Constructor) ============
    
    constructor(address _tokenAddress) validAddress(_tokenAddress) {
        require(_tokenAddress != address(0), "عنوان الرمز صحيح");
        token = IERC20(_tokenAddress);
        feeCollector = msg.sender;
    }

    // ============ الدوال الرئيسية (Main Functions) ============
    
    /**
     * @notice إنشاء تعامل جديد
     * @dev تحقق من الأمان: Checks-Effects-Interactions
     * @param _seller عنوان البائع
     * @param _price السعر بالرموز
     * @param _tokenAmount عدد الرموز المراد نقلها
     * @param _metadata وصف التعامل
     * @return dealId معرف التعامل الفريد
     */
    function createDeal(
        address _seller,
        uint256 _price,
        uint256 _tokenAmount,
        string memory _metadata
    ) 
        external 
        onlyActive 
        validAddress(_seller)
        returns (bytes32 dealId) 
    {
        // ============ Checks ============
        require(_seller != msg.sender, "البائع والمشتري يجب أن يكونا مختلفين");
        require(_price > 0, "السعر يجب أن يكون أكبر من صفر");
        require(_tokenAmount > 0, "عدد الرموز يجب أن يكون أكبر من صفر");
        require(bytes(_metadata).length <= 500, "وصف التعامل طويل جداً");
        
        // تحقق من الموافقة المسبقة
        require(
            token.allowance(msg.sender, address(this)) >= _price,
            "موافقة غير كافية - يجب الموافقة أولاً"
        );

        // ============ Effects ============
        dealId = keccak256(abi.encodePacked(
            msg.sender,
            _seller,
            _price,
            block.timestamp,
            dealCounter
        ));
        
        deals[dealId] = Deal({
            buyer: msg.sender,
            seller: _seller,
            price: _price,
            tokenAmount: _tokenAmount,
            isSettled: false,
            isCancelled: false,
            createdAt: block.timestamp,
            settledAt: 0,
            dealMetadata: _metadata
        });
        
        userDealHistory[msg.sender].push(dealId);
        userDealHistory[_seller].push(dealId);
        userProfiles[msg.sender].totalDeals += 1;
        userProfiles[_seller].totalDeals += 1;
        
        dealCounter += 1;

        // ============ Interactions ============
        emit DealCreated(
            dealId,
            msg.sender,
            _seller,
            _price,
            _tokenAmount,
            block.timestamp
        );
    }

    /**
     * @notice تنفيذ التسوية الذرية
     * @dev تحويل الرموز بشكل آمن من المشتري إلى البائع
     * @param _dealId معرف التعامل
     */
    function executeAtomicSettlement(bytes32 _dealId)
        external
        nonReentrant
        onlyActive
        validDealId(_dealId)
    {
        Deal storage deal = deals[_dealId];
        
        // ============ Checks ============
        require(!deal.isSettled, "التعامل تم تسويته مسبقاً");
        require(!deal.isCancelled, "التعامل تم إلغاؤه");
        require(deal.buyer == msg.sender, "فقط المشتري يمكنه تنفيذ التسوية");
        require(deal.price > 0, "السعر غير صحيح");

        // ============ Effects ============
        // سجل التسوية أولاً لمنع الهجمات
        deal.isSettled = true;
        deal.settledAt = block.timestamp;
        
        userProfiles[deal.buyer].successfulDeals += 1;
        userProfiles[deal.seller].successfulDeals += 1;
        userProfiles[deal.buyer].totalVolume += deal.price;
        userProfiles[deal.seller].totalVolume += deal.price;
        
        // زيادة السمعة
        _increaseReputation(deal.buyer, 10);
        _increaseReputation(deal.seller, 10);

        // ============ Interactions ============
        // حساب الرسوم
        uint256 feeAmount = (deal.price * settlementFeePercentage) / 10000;
        uint256 sellerAmount = deal.price - feeAmount;
        
        // نقل الرموز بأمان
        token.safeTransferFrom(deal.buyer, deal.seller, sellerAmount);
        
        if (feeAmount > 0) {
            token.safeTransferFrom(deal.buyer, feeCollector, feeAmount);
            emit FeeCollected(feeAmount, block.timestamp);
        }
        
        emit DealSettled(
            _dealId,
            deal.buyer,
            deal.seller,
            deal.price,
            block.timestamp
        );
    }

    /**
     * @notice إلغاء التعامل
     * @param _dealId معرف التعامل
     * @param _reason سبب الإلغاء
     */
    function cancelDeal(bytes32 _dealId, string memory _reason)
        external
        validDealId(_dealId)
    {
        Deal storage deal = deals[_dealId];
        
        require(!deal.isSettled, "لا يمكن إلغاء تعامل تم تسويته");
        require(!deal.isCancelled, "التعامل مُلغى مسبقاً");
        require(
            msg.sender == deal.buyer || msg.sender == deal.seller || msg.sender == owner(),
            "لا توجد صلاحية للإلغاء"
        );
        
        deal.isCancelled = true;
        
        // تقليل السمعة قليلاً
        _decreaseReputation(deal.buyer, 2);
        _decreaseReputation(deal.seller, 2);
        
        emit DealCancelled(_dealId, msg.sender, _reason, block.timestamp);
    }

    /**
     * @notice سحب طوارئ - للمالك فقط في حالات الطوارئ
     * @param _to العنوان المستقبل
     * @param _amount المبلغ
     */
    function emergencyWithdraw(address _to, uint256 _amount)
        external
        onlyOwner
        validAddress(_to)
    {
        require(_amount > 0, "المبلغ يجب أن يكون أكبر من صفر");
        require(
            token.balanceOf(address(this)) >= _amount,
            "رصيد غير كافي"
        );
        
        token.safeTransfer(_to, _amount);
        
        emit EmergencyWithdraw(_to, _amount, block.timestamp);
    }

    // ============ دوال معلومات المستخدم (User Info Functions) ============
    
    /**
     * @notice الحصول على معلومات المشتري
     */
    function getUserProfile(address _user)
        external
        view
        returns (UserProfile memory)
    {
        return userProfiles[_user];
    }

    /**
     * @notice الحصول على معلومات التعامل
     */
    function getDeal(bytes32 _dealId)
        external
        view
        validDealId(_dealId)
        returns (Deal memory)
    {
        return deals[_dealId];
    }

    /**
     * @notice الحصول على سجل تعاملات المستخدم
     */
    function getUserDealHistory(address _user)
        external
        view
        returns (bytes32[] memory)
    {
        return userDealHistory[_user];
    }

    /**
     * @notice الحصول على عدد التعاملات
     */
    function getUserDealCount(address _user)
        external
        view
        returns (uint256)
    {
        return userDealHistory[_user].length;
    }

    // ============ دوال الإدارة (Admin Functions) ============
    
    /**
     * @notice تعديل نسبة الرسوم
     */
    function setSettlementFee(uint256 _newFeePercentage)
        external
        onlyOwner
    {
        require(_newFeePercentage <= 500, "الرسوم لا يمكن أن تتجاوز 5%");
        settlementFeePercentage = _newFeePercentage;
    }

    /**
     * @notice تعديل عنوان جامع الرسوم
     */
    function setFeeCollector(address _newCollector)
        external
        onlyOwner
        validAddress(_newCollector)
    {
        feeCollector = _newCollector;
    }

    /**
     * @notice تفعيل/تعطيل العقد
     */
    function setContractActive(bool _isActive)
        external
        onlyOwner
    {
        isContractActive = _isActive;
    }

    // ============ دوال السمعة الداخلية (Internal Reputation Functions) ============
    
    function _increaseReputation(address _user, uint256 _points) internal {
        userProfiles[_user].reputation += _points;
        userProfiles[_user].isActive = true;
        emit ReputationUpdated(_user, userProfiles[_user].reputation, true);
    }

    function _decreaseReputation(address _user, uint256 _points) internal {
        if (userProfiles[_user].reputation >= _points) {
            userProfiles[_user].reputation -= _points;
        } else {
            userProfiles[_user].reputation = 0;
        }
        emit ReputationUpdated(_user, userProfiles[_user].reputation, false);
    }

    // ============ دوال إضافية مفيدة (Utility Functions) ============
    
    /**
     * @notice الحصول على معلومات الرمز
     */
    function getTokenInfo()
        external
        view
        returns (
            string memory name,
            string memory symbol,
            uint8 decimals
        )
    {
        IERC20Extended tokenExt = IERC20Extended(address(token));
        return (
            tokenExt.name(),
            tokenExt.symbol(),
            tokenExt.decimals()
        );
    }

    /**
     * @notice الحصول على إحصائيات العقد
     */
    function getContractStats()
        external
        view
        returns (
            uint256 totalDeals,
            uint256 contractBalance,
            bool isActive
        )
    {
        return (
            dealCounter,
            token.balanceOf(address(this)),
            isContractActive
        );
    }
}
