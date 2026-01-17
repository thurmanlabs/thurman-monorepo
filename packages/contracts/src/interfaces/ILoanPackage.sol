// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*//////////////////////////////////////////////////////////////
                    LOAN PACKAGE (ERC1155 + METADATA)
//////////////////////////////////////////////////////////////*/

/// @title ILoanPackage
/// @notice ERC1155 token representing fractional ownership of loan packages
/// @dev Combines token mechanics with package metadata in a single contract
interface ILoanPackage {
    // ═══════════════════════════════════════════════════════════════════════
    //                              ERRORS
    // ═══════════════════════════════════════════════════════════════════════

    error PackageAlreadyExists(uint256 packageId);
    error PackageNotFound(uint256 packageId);
    error InvalidTotalSupply();
    error InvalidSalePrice();
    error TransfersDisabled();
    error InvalidStatusTransition(PackageStatus current, PackageStatus target);

    // ═══════════════════════════════════════════════════════════════════════
    //                              EVENTS
    // ═══════════════════════════════════════════════════════════════════════

    event PackageCreated(
        uint256 indexed packageId,
        address indexed seller,
        uint256 totalSupply,
        uint256 salePrice,
        PackageType packageType,
        bytes32 loanTapeHash
    );

    event PackageStatusUpdated(
        uint256 indexed packageId,
        uint8 oldStatus,
        uint8 newStatus
    );

    event PackageDefaulted(
        uint256 indexed packageId,
        uint256 timestamp
    );

    // ═══════════════════════════════════════════════════════════════════════
    //                              TYPES
    // ═══════════════════════════════════════════════════════════════════════

    enum PackageStatus {
        Created,        // Package created, awaiting escrow
        Escrowed,       // Tokens deposited in escrow, awaiting buyer USDC
        Settled,        // DvP completed, tokens distributed to buyers
        Active,         // Collecting servicing payments
        Closed,         // All loans paid off
        Defaulted       // Package experienced default
    }

    enum PackageType {
        Package,
        Single
    }

    struct PackageMetadata {
        address seller;
        uint256 totalSupply;        // Total tokens (e.g., 100,000 for $100k package)
        uint256 salePrice;          // Total USDC needed (e.g., 100,000 USDC)
        bytes32 loanTapeHash;       // Hash of loan CSV data
        string packageName;         // e.g., "Manufacturing Growth Fund Q1"
        string description;
        PackageStatus status;
        PackageType packageType;
        uint256 createdAt;
        uint256 settledAt;
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                         PACKAGE LIFECYCLE
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Creates a new loan package with metadata and token setup
    /// @param totalSupply Total number of tokens (e.g., 100,000 for $100k package)
    /// @param salePrice Total USDC needed to purchase the package
    /// @param packageType Type of package (Package or Single)
    /// @param loanTapeHash Hash of the loan tape CSV data
    /// @param packageName Human-readable package name
    /// @param description Package description
    /// @return packageId The auto-generated unique identifier for the loan package
    function createPackage(
        uint256 totalSupply,
        uint256 salePrice,
        PackageType packageType,
        bytes32 loanTapeHash,
        string calldata packageName,
        string calldata description
    ) external returns (uint256 packageId);

    /// @notice Update package status
    /// @param packageId The loan package ID
    /// @param newStatus The new status to set
    function updateStatus(
        uint256 packageId,
        PackageStatus newStatus
    ) external;

    /// @notice Get package metadata
    /// @param packageId The loan package ID
    /// @return Package metadata struct
    function getPackage(
        uint256 packageId
    ) external view returns (PackageMetadata memory);

    /// @notice Get all active packages (status = Active)
    /// @return Array of package IDs that are currently active
    function getActivePackages() external view returns (uint256[] memory);

    /// @notice Mark package as defaulted
    /// @param packageId The loan package ID
    function markDefaulted(uint256 packageId) external;

    // ═══════════════════════════════════════════════════════════════════════
    //                         TOKEN OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Mints tokens to buyer after DvP settlement
    /// @param packageId The loan package ID
    /// @param to Buyer address receiving tokens
    /// @param amount Number of tokens to mint
    function mint(
        uint256 packageId,
        address to,
        uint256 amount
    ) external;

    /// @notice Burns tokens (for write-downs or redemptions)
    /// @param packageId The loan package ID
    /// @param from Address to burn tokens from
    /// @param amount Number of tokens to burn
    function burn(
        uint256 packageId,
        address from,
        uint256 amount
    ) external;

    /// @notice Returns total supply for a package
    /// @param packageId The loan package ID
    /// @return Total token supply for this package
    function totalSupply(uint256 packageId) external view returns (uint256);

    /// @notice Returns token balance for an account
    /// @param account The address to check
    /// @param packageId The loan package ID
    /// @return Token balance
    function balanceOf(
        address account,
        uint256 packageId
    ) external view returns (uint256);

    /// @notice Returns all token holders for a package (for distribution)
    /// @param packageId The loan package ID
    /// @return Array of holder addresses
    function getHolders(
        uint256 packageId
    ) external view returns (address[] memory);

    // NOTE: safeTransferFrom should be disabled in implementation to prevent secondary transfers
}