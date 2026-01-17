// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { ILoanPackage } from "./interfaces/ILoanPackage.sol";
import { ThurmanRoles } from "./ThurmanRoles.sol";
import { ThurmanBase } from "./ThurmanBase.sol";

/// @title LoanPackage
/// @notice ERC1155 token representing fractional ownership of loan packages
/// @dev Combines token mechanics with package metadata in a single contract
/// @dev Tokens are non-transferable to prevent secondary market trading
contract LoanPackage is ERC1155, Ownable, ThurmanBase, ILoanPackage {
    using EnumerableSet for EnumerableSet.AddressSet;

    // ═══════════════════════════════════════════════════════════════════════
    //                              STATE
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Package metadata by package ID
    mapping(uint256 => PackageMetadata) private _packages;

    /// @notice Token holders for each package (for pro-rata distribution)
    mapping(uint256 => EnumerableSet.AddressSet) private _holders;

    /// @notice Total supply per package ID
    mapping(uint256 => uint256) private _totalSupply;

    /// @notice Array of active package IDs
    uint256[] private _activePackageIds;

    /// @notice Index tracking for active packages (for efficient removal)
    mapping(uint256 => uint256) private _activePackageIndex;

    /// @notice Whether a package exists
    mapping(uint256 => bool) private _packageExists;

    /// @notice Counter for auto-incrementing package IDs
    uint256 private _nextPackageId;

    // ═══════════════════════════════════════════════════════════════════════
    //                            CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════════

    /// @param owner_ Address to set as contract owner
    /// @param platformConfig_ Platform configuration contract address
    /// @param roleRegistry_ Role registry contract address
    constructor(
        address owner_,
        address platformConfig_,
        address roleRegistry_
    ) ERC1155("") Ownable(owner_) ThurmanBase(platformConfig_, roleRegistry_) {}

    // ═══════════════════════════════════════════════════════════════════════
    //                              MODIFIERS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Reverts if package doesn't exist
    modifier packageExists(uint256 packageId) {
        _onlyPackageExists(packageId);
        _;
    }

    function _onlyPackageExists(uint256 packageId) internal view {
        if (!_packageExists[packageId]) revert PackageNotFound(packageId);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                         PACKAGE LIFECYCLE
    // ═══════════════════════════════════════════════════════════════════════

    /// @inheritdoc ILoanPackage
    function createPackage(
        uint256 totalSupply_,
        uint256 salePrice,
        PackageType packageType,
        bytes32 loanTapeHash,
        string calldata packageName,
        string calldata description
    ) external onlyRole(ThurmanRoles.SELLER_ROLE) whenNotPaused returns (uint256 packageId) {
        if (totalSupply_ == 0) revert InvalidTotalSupply();
        if (salePrice == 0) revert InvalidSalePrice();

        packageId = _nextPackageId++;
        _packageExists[packageId] = true;
        _packages[packageId] = PackageMetadata({
            seller: msg.sender,
            totalSupply: totalSupply_,
            salePrice: salePrice,
            loanTapeHash: loanTapeHash,
            packageName: packageName,
            description: description,
            status: PackageStatus.Created,
            packageType: packageType,
            createdAt: block.timestamp,
            settledAt: 0
        });

        emit PackageCreated(packageId, msg.sender, totalSupply_, salePrice, packageType, loanTapeHash);
    }

    /// @inheritdoc ILoanPackage
    function updateStatus(
        uint256 packageId,
        PackageStatus newStatus
    ) external packageExists(packageId) whenNotPaused {
        // Only admin or minter (DvPEscrow) can update status
        bool isAdmin = roleRegistry.hasRole(ThurmanRoles.ADMIN_ROLE, msg.sender);
        bool isMinter = roleRegistry.hasRole(ThurmanRoles.MINTER_ROLE, msg.sender);
        
        if (!isAdmin || !isMinter) {
            revert NotAuthorized(msg.sender, ThurmanRoles.MINTER_ROLE);
        }

        PackageMetadata storage pkg = _packages[packageId];
        PackageStatus oldStatus = pkg.status;

        // Validate status transitions
        _validateStatusTransition(oldStatus, newStatus);

        pkg.status = newStatus;

        // Track settled timestamp
        if (newStatus == PackageStatus.Settled) {
            pkg.settledAt = block.timestamp;
        }

        // Manage active packages list
        if (newStatus == PackageStatus.Active && oldStatus != PackageStatus.Active) {
            _addToActivePackages(packageId);
        } else if (oldStatus == PackageStatus.Active && newStatus != PackageStatus.Active) {
            _removeFromActivePackages(packageId);
        }

        emit PackageStatusUpdated(packageId, uint8(oldStatus), uint8(newStatus));
    }

    /// @inheritdoc ILoanPackage
    function getPackage(
        uint256 packageId
    ) external view packageExists(packageId) returns (PackageMetadata memory) {
        return _packages[packageId];
    }

    /// @inheritdoc ILoanPackage
    function getActivePackages() external view returns (uint256[] memory) {
        return _activePackageIds;
    }

    /// @inheritdoc ILoanPackage
    function markDefaulted(uint256 packageId) external onlyRole(ThurmanRoles.ADMIN_ROLE) packageExists(packageId) {
        PackageMetadata storage pkg = _packages[packageId];
        PackageStatus oldStatus = pkg.status;

        // Can only default active packages
        if (oldStatus != PackageStatus.Active) {
            revert InvalidStatusTransition(oldStatus, PackageStatus.Defaulted);
        }

        pkg.status = PackageStatus.Defaulted;
        _removeFromActivePackages(packageId);

        emit PackageStatusUpdated(packageId, uint8(oldStatus), uint8(PackageStatus.Defaulted));
        emit PackageDefaulted(packageId, block.timestamp);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                         TOKEN OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// @inheritdoc ILoanPackage
    function mint(
        uint256 packageId,
        address to,
        uint256 amount
    ) external onlyRole(ThurmanRoles.MINTER_ROLE) packageExists(packageId) whenNotPaused {
        if (to == address(0)) revert ZeroAddress();

        // Effects before interactions (CEI pattern)
        _totalSupply[packageId] += amount;
        _holders[packageId].add(to);

        // Interaction last - _mint triggers onERC1155Received callback
        _mint(to, packageId, amount, "");
    }

    /// @inheritdoc ILoanPackage
    function burn(
        uint256 packageId,
        address from,
        uint256 amount
    ) external onlyRole(ThurmanRoles.ADMIN_ROLE) packageExists(packageId) {
        _burn(from, packageId, amount);
        _totalSupply[packageId] -= amount;

        // Remove from holders if balance is now zero
        if (balanceOf(from, packageId) == 0) {
            _holders[packageId].remove(from);
        }
    }

    /// @inheritdoc ILoanPackage
    function totalSupply(uint256 packageId) external view returns (uint256) {
        return _totalSupply[packageId];
    }

    /// @inheritdoc ILoanPackage
    function balanceOf(
        address account,
        uint256 packageId
    ) public view override(ERC1155, ILoanPackage) returns (uint256) {
        return super.balanceOf(account, packageId);
    }

    /// @inheritdoc ILoanPackage
    function getHolders(
        uint256 packageId
    ) external view packageExists(packageId) returns (address[] memory) {
        return _holders[packageId].values();
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                         TRANSFER OVERRIDES
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Disabled - tokens are non-transferable
    function safeTransferFrom(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public pure override {
        revert TransfersDisabled();
    }

    /// @notice Disabled - tokens are non-transferable
    function safeBatchTransferFrom(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public pure override {
        revert TransfersDisabled();
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                         INTERNAL FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Validates status transitions
    function _validateStatusTransition(
        PackageStatus current,
        PackageStatus target
    ) internal pure {
        // Valid transitions:
        // Created -> Escrowed
        // Escrowed -> Settled, Created (refund)
        // Settled -> Active
        // Active -> Closed, Defaulted

        bool valid = false;

        if (current == PackageStatus.Created && target == PackageStatus.Escrowed) {
            valid = true;
        } else if (current == PackageStatus.Escrowed && 
                   (target == PackageStatus.Settled || target == PackageStatus.Created)) {
            valid = true;
        } else if (current == PackageStatus.Settled && target == PackageStatus.Active) {
            valid = true;
        } else if (current == PackageStatus.Active && 
                   (target == PackageStatus.Closed || target == PackageStatus.Defaulted)) {
            valid = true;
        }

        if (!valid) {
            revert InvalidStatusTransition(current, target);
        }
    }

    /// @notice Adds package to active list
    function _addToActivePackages(uint256 packageId) internal {
        _activePackageIndex[packageId] = _activePackageIds.length;
        _activePackageIds.push(packageId);
    }

    /// @notice Removes package from active list
    function _removeFromActivePackages(uint256 packageId) internal {
        uint256 index = _activePackageIndex[packageId];
        uint256 lastIndex = _activePackageIds.length - 1;

        if (index != lastIndex) {
            uint256 lastPackageId = _activePackageIds[lastIndex];
            _activePackageIds[index] = lastPackageId;
            _activePackageIndex[lastPackageId] = index;
        }

        _activePackageIds.pop();
        delete _activePackageIndex[packageId];
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                         ERC165 SUPPORT
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Returns true if this contract implements the interface
    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        override(ERC1155) 
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    }
}
