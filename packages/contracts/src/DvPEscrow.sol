// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { IDvPEscrow } from "./interfaces/IDvPEscrow.sol";
import { ILoanPackage } from "./interfaces/ILoanPackage.sol";
import { ThurmanRoles } from "./ThurmanRoles.sol";
import { ThurmanBase } from "./ThurmanBase.sol";

/// @title DvPEscrow
/// @notice Handles atomic delivery-vs-payment settlement for loan packages
/// @dev Uses Arc's native USDC (18 decimals) for payments via msg.value
contract DvPEscrow is IDvPEscrow, Ownable, ReentrancyGuard, ThurmanBase {
    using EnumerableSet for EnumerableSet.AddressSet;

    // ═══════════════════════════════════════════════════════════════════════
    //                              STATE
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Loan package contract
    ILoanPackage public immutable loanPackage;

    /// @notice Escrow positions by package ID and buyer
    mapping(uint256 => mapping(address => EscrowPosition)) private _positions;

    /// @notice Buyers for each package
    mapping(uint256 => EnumerableSet.AddressSet) private _buyers;

    /// @notice Total USDC deposited per package
    mapping(uint256 => uint256) private _totalDeposited;

    /// @notice Whether a package is in escrow
    mapping(uint256 => bool) private _isEscrowed;

    /// @notice Token amount escrowed per package
    mapping(uint256 => uint256) private _escrowedTokens;

    // ═══════════════════════════════════════════════════════════════════════
    //                            CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════════

    /// @param owner_ Address to set as contract owner
    /// @param platformConfig_ Platform configuration contract address
    /// @param loanPackage_ Loan package contract address
    /// @param roleRegistry_ Role registry contract address
    constructor(
        address owner_,
        address platformConfig_,
        address loanPackage_,
        address roleRegistry_
    ) Ownable(owner_) ThurmanBase(platformConfig_, roleRegistry_) {
        if (loanPackage_ == address(0)) revert ZeroAddress();

        loanPackage = ILoanPackage(loanPackage_);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                         SELLER FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// @inheritdoc IDvPEscrow
    function depositTokens(
        uint256 packageId,
        uint256 tokenAmount
    ) external onlyRole(ThurmanRoles.SELLER_ROLE) whenNotPaused nonReentrant {
        // Get package metadata
        ILoanPackage.PackageMetadata memory pkg = loanPackage.getPackage(packageId);

        // Verify caller is the seller
        if (pkg.seller != msg.sender) {
            revert NotPackageSeller(msg.sender, pkg.seller);
        }

        // Verify package is in Created status
        if (pkg.status != ILoanPackage.PackageStatus.Created) {
            revert InvalidPackageStatus();
        }

        // Verify token amount matches total supply
        if (tokenAmount != pkg.totalSupply) {
            revert InvalidTokenAmount(pkg.totalSupply, tokenAmount);
        }

        // Verify not already escrowed
        if (_isEscrowed[packageId]) {
            revert PackageAlreadyEscrowed(packageId);
        }

        // Mark as escrowed
        _isEscrowed[packageId] = true;
        _escrowedTokens[packageId] = tokenAmount;

        // Update package status to Escrowed
        loanPackage.updateStatus(packageId, ILoanPackage.PackageStatus.Escrowed);

        emit TokensEscrowed(packageId, msg.sender, tokenAmount);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                         BUYER FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// @inheritdoc IDvPEscrow
    function depositUSDC(uint256 packageId) external payable onlyRole(ThurmanRoles.BUYER_ROLE) whenNotPaused nonReentrant {
        if (msg.value == 0) revert ZeroDeposit();
        if (!_isEscrowed[packageId]) revert PackageNotEscrowed(packageId);

        // Get package to verify it's still in Escrowed status
        ILoanPackage.PackageMetadata memory pkg = loanPackage.getPackage(packageId);
        if (pkg.status != ILoanPackage.PackageStatus.Escrowed) {
            revert InvalidPackageStatus();
        }

        // Update position
        EscrowPosition storage position = _positions[packageId][msg.sender];
        position.packageId = packageId;
        position.buyer = msg.sender;
        position.usdcAmount += msg.value;

        // Calculate tokens owed based on contribution
        // tokens = (usdcDeposited / salePrice) * totalSupply
        position.tokensOwed = (position.usdcAmount * pkg.totalSupply) / pkg.salePrice;

        // Add to buyers set
        _buyers[packageId].add(msg.sender);

        // Update total deposited
        _totalDeposited[packageId] += msg.value;

        emit USDCDeposited(packageId, msg.sender, msg.value, _totalDeposited[packageId]);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                         ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// @inheritdoc IDvPEscrow
    function settle(uint256 packageId) external onlyRole(ThurmanRoles.ADMIN_ROLE) whenNotPaused nonReentrant {
        if (!_isEscrowed[packageId]) revert PackageNotEscrowed(packageId);

        ILoanPackage.PackageMetadata memory pkg = loanPackage.getPackage(packageId);
        
        // Verify package is in Escrowed status
        if (pkg.status != ILoanPackage.PackageStatus.Escrowed) {
            revert InvalidPackageStatus();
        }

        // Verify sufficient deposits
        uint256 totalDeposited = _totalDeposited[packageId];
        if (totalDeposited < pkg.salePrice) {
            revert InsufficientDeposits(pkg.salePrice, totalDeposited);
        }

        // Calculate platform fee
        uint256 feeBps = platformConfig.getPlatformFeeBps();
        uint256 fee = (totalDeposited * feeBps) / 10000;
        uint256 sellerAmount = totalDeposited - fee;

        // Transfer fee to platform
        if (fee > 0) {
            address feeRecipient = platformConfig.getFeeRecipient();
            (bool feeSuccess, ) = payable(feeRecipient).call{value: fee}("");
            if (!feeSuccess) revert TransferFailed(feeRecipient, fee);
        }

        // Transfer USDC to seller
        (bool sellerSuccess, ) = payable(pkg.seller).call{value: sellerAmount}("");
        if (!sellerSuccess) revert TransferFailed(pkg.seller, sellerAmount);

        // Mint tokens to all buyers
        address[] memory buyers = _buyers[packageId].values();
        for (uint256 i = 0; i < buyers.length; i++) {
            EscrowPosition storage position = _positions[packageId][buyers[i]];
            if (position.tokensOwed > 0 && !position.settled) {
                position.settled = true;
                loanPackage.mint(packageId, buyers[i], position.tokensOwed);
            }
        }

        // Update package status to Settled
        loanPackage.updateStatus(packageId, ILoanPackage.PackageStatus.Settled);

        emit DealSettled(packageId, pkg.seller, totalDeposited, buyers.length);
    }

    /// @inheritdoc IDvPEscrow
    function refund(uint256 packageId) external onlyRole(ThurmanRoles.ADMIN_ROLE) whenNotPaused nonReentrant {
        if (!_isEscrowed[packageId]) revert PackageNotEscrowed(packageId);

        ILoanPackage.PackageMetadata memory pkg = loanPackage.getPackage(packageId);
        
        // Verify package is in Escrowed status
        if (pkg.status != ILoanPackage.PackageStatus.Escrowed) {
            revert InvalidPackageStatus();
        }

        uint256 totalRefunded = 0;

        // Refund all buyers
        address[] memory buyers = _buyers[packageId].values();
        for (uint256 i = 0; i < buyers.length; i++) {
            EscrowPosition storage position = _positions[packageId][buyers[i]];
            uint256 refundAmount = position.usdcAmount;
            
            if (refundAmount > 0 && !position.settled) {
                position.usdcAmount = 0;
                position.tokensOwed = 0;
                totalRefunded += refundAmount;

                (bool success, ) = payable(buyers[i]).call{value: refundAmount}("");
                if (!success) revert TransferFailed(buyers[i], refundAmount);
            }
        }

        // Reset escrow state
        _isEscrowed[packageId] = false;
        _totalDeposited[packageId] = 0;
        _escrowedTokens[packageId] = 0;

        // Update package status back to Created
        loanPackage.updateStatus(packageId, ILoanPackage.PackageStatus.Created);

        emit DealRefunded(packageId, totalRefunded);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                         VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// @inheritdoc IDvPEscrow
    function totalUSDCDeposited(uint256 packageId) external view returns (uint256) {
        return _totalDeposited[packageId];
    }

    /// @inheritdoc IDvPEscrow
    function getPosition(
        uint256 packageId,
        address buyer
    ) external view returns (EscrowPosition memory) {
        return _positions[packageId][buyer];
    }

    /// @inheritdoc IDvPEscrow
    function getBuyers(uint256 packageId) external view returns (address[] memory) {
        return _buyers[packageId].values();
    }

    /// @inheritdoc IDvPEscrow
    function canSettle(uint256 packageId) external view returns (bool) {
        if (!_isEscrowed[packageId]) return false;

        ILoanPackage.PackageMetadata memory pkg = loanPackage.getPackage(packageId);
        return _totalDeposited[packageId] >= pkg.salePrice;
    }
}
