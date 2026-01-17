// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { IServicingManager } from "./interfaces/IServicingManager.sol";
import { ILoanPackage } from "./interfaces/ILoanPackage.sol";
import { ThurmanRoles } from "./ThurmanRoles.sol";
import { ThurmanBase } from "./ThurmanBase.sol";

/// @title ServicingManager
/// @notice Handles payment recording and pro-rata distribution to token holders
/// @dev Uses Arc's native USDC (18 decimals) for payments via msg.value
contract ServicingManager is IServicingManager, Ownable, ReentrancyGuard, ThurmanBase {
    // ═══════════════════════════════════════════════════════════════════════
    //                              STATE
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Loan package contract
    ILoanPackage public immutable loanPackage;

    /// @notice Servicing snapshots per package
    mapping(uint256 => ServicingSnapshot[]) private _snapshots;

    /// @notice Total principal collected per package
    mapping(uint256 => uint256) private _totalPrincipalCollected;

    /// @notice Total interest collected per package
    mapping(uint256 => uint256) private _totalInterestCollected;

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

    /// @inheritdoc IServicingManager
    function recordPayment(
        uint256 packageId,
        uint256 principalAmount,
        uint256 interestAmount,
        bytes32 servicingDataHash
    ) external payable onlyRole(ThurmanRoles.SELLER_ROLE) whenNotPaused nonReentrant {
        uint256 totalPayment = principalAmount + interestAmount;
        
        // Validate payment
        if (totalPayment == 0) revert ZeroPayment();
        if (msg.value != totalPayment) revert PaymentMismatch(totalPayment, msg.value);

        // Get package metadata
        ILoanPackage.PackageMetadata memory pkg = loanPackage.getPackage(packageId);

        // Verify caller is the seller
        if (pkg.seller != msg.sender) {
            revert NotPackageSeller(msg.sender, pkg.seller);
        }

        // Verify package is Active
        if (pkg.status != ILoanPackage.PackageStatus.Active) {
            revert PackageNotActive(packageId);
        }

        // Update totals
        _totalPrincipalCollected[packageId] += principalAmount;
        _totalInterestCollected[packageId] += interestAmount;

        // Calculate principal outstanding
        uint256 principalOutstanding = pkg.salePrice > _totalPrincipalCollected[packageId] 
            ? pkg.salePrice - _totalPrincipalCollected[packageId]
            : 0;

        // Create snapshot
        _snapshots[packageId].push(ServicingSnapshot({
            timestamp: block.timestamp,
            principalCollected: principalAmount,
            interestCollected: interestAmount,
            principalOutstanding: principalOutstanding,
            servicingDataHash: servicingDataHash
        }));

        emit PaymentRecorded(packageId, principalAmount, interestAmount, servicingDataHash, block.timestamp);

        // Distribute payment to holders pro-rata
        _distributePayment(packageId, totalPayment, pkg.totalSupply);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                         VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// @inheritdoc IServicingManager
    function getLatestSnapshot(
        uint256 packageId
    ) external view returns (ServicingSnapshot memory) {
        ServicingSnapshot[] storage snapshots = _snapshots[packageId];
        if (snapshots.length == 0) revert NoSnapshots(packageId);
        return snapshots[snapshots.length - 1];
    }

    /// @inheritdoc IServicingManager
    function getSnapshots(
        uint256 packageId
    ) external view returns (ServicingSnapshot[] memory) {
        return _snapshots[packageId];
    }

    /// @inheritdoc IServicingManager
    function getTotalPrincipalCollected(
        uint256 packageId
    ) external view returns (uint256) {
        return _totalPrincipalCollected[packageId];
    }

    /// @inheritdoc IServicingManager
    function getTotalInterestCollected(
        uint256 packageId
    ) external view returns (uint256) {
        return _totalInterestCollected[packageId];
    }

    /// @inheritdoc IServicingManager
    function calculateDistribution(
        uint256 packageId,
        address holder,
        uint256 paymentAmount
    ) external view returns (uint256) {
        uint256 totalSupply = loanPackage.totalSupply(packageId);
        if (totalSupply == 0) return 0;

        uint256 holderBalance = loanPackage.balanceOf(holder, packageId);
        return (holderBalance * paymentAmount) / totalSupply;
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                         INTERNAL FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Distributes payment to all token holders pro-rata
    /// @param packageId The loan package ID
    /// @param totalPayment Total payment amount to distribute
    /// @param totalSupply Total token supply for the package
    function _distributePayment(
        uint256 packageId,
        uint256 totalPayment,
        uint256 totalSupply
    ) internal {
        // Get all holders
        address[] memory holders = loanPackage.getHolders(packageId);

        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];
            uint256 holderBalance = loanPackage.balanceOf(holder, packageId);

            if (holderBalance > 0) {
                // Calculate pro-rata share
                uint256 share = (holderBalance * totalPayment) / totalSupply;

                if (share > 0) {
                    // Transfer native USDC to holder
                    (bool success, ) = payable(holder).call{value: share}("");
                    if (!success) revert TransferFailed(holder, share);

                    emit PaymentDistributed(packageId, holder, share);
                }
            }
        }
    }
}
