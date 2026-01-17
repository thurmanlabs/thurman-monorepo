// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*//////////////////////////////////////////////////////////////
                    DvP ESCROW (DELIVERY VS PAYMENT)
//////////////////////////////////////////////////////////////*/

/// @title IDvPEscrow
/// @notice Handles atomic delivery-vs-payment settlement for loan packages
/// @dev Uses Arc's native USDC (18 decimals) for payments via msg.value
interface IDvPEscrow {
    // ═══════════════════════════════════════════════════════════════════════
    //                              ERRORS
    // ═══════════════════════════════════════════════════════════════════════

    error PackageNotFound(uint256 packageId);
    error PackageNotEscrowed(uint256 packageId);
    error PackageAlreadyEscrowed(uint256 packageId);
    error PackageAlreadySettled(uint256 packageId);
    error InvalidTokenAmount(uint256 expected, uint256 provided);
    error ZeroDeposit();
    error InsufficientDeposits(uint256 required, uint256 deposited);
    error TransferFailed(address to, uint256 amount);
    error NotPackageSeller(address caller, address seller);
    error InvalidPackageStatus();

    // ═══════════════════════════════════════════════════════════════════════
    //                              EVENTS
    // ═══════════════════════════════════════════════════════════════════════

    event TokensEscrowed(
        uint256 indexed packageId,
        address indexed seller,
        uint256 amount
    );

    event USDCDeposited(
        uint256 indexed packageId,
        address indexed buyer,
        uint256 amount,
        uint256 totalDeposited
    );

    event DealSettled(
        uint256 indexed packageId,
        address indexed seller,
        uint256 totalUSDC,
        uint256 buyerCount
    );

    event DealRefunded(
        uint256 indexed packageId,
        uint256 totalRefunded
    );

    // ═══════════════════════════════════════════════════════════════════════
    //                              TYPES
    // ═══════════════════════════════════════════════════════════════════════

    struct EscrowPosition {
        uint256 packageId;
        address buyer;
        uint256 usdcAmount;         // Native USDC deposited by this buyer (18 decimals)
        uint256 tokensOwed;         // Tokens they'll receive on settlement
        bool settled;
    }

    /// @notice Seller initiates sale by escrowing tokens
    /// @param packageId The loan package being sold
    /// @param tokenAmount Number of tokens to escrow (must equal totalSupply)
    function depositTokens(
        uint256 packageId,
        uint256 tokenAmount
    ) external;

    /// @notice Buyer deposits native USDC to purchase tokens
    /// @param packageId The loan package to buy into
    /// @dev Send native USDC via msg.value (18 decimals)
    function depositUSDC(uint256 packageId) external payable;

    /// @notice Returns total native USDC deposited for a package
    /// @param packageId The loan package ID
    /// @return Total native USDC deposited (18 decimals)
    function totalUSDCDeposited(
        uint256 packageId
    ) external view returns (uint256);

    /// @notice Returns buyer's escrow position
    /// @param packageId The loan package ID
    /// @param buyer The buyer address
    /// @return EscrowPosition struct
    function getPosition(
        uint256 packageId,
        address buyer
    ) external view returns (EscrowPosition memory);

    /// @notice Returns all buyers for a package
    /// @param packageId The loan package ID
    /// @return Array of buyer addresses
    function getBuyers(
        uint256 packageId
    ) external view returns (address[] memory);

    /// @notice Admin settles the deal - atomic DvP swap
    /// @dev Transfers native USDC to seller, mints tokens to buyers pro-rata
    /// @param packageId The loan package ID
    function settle(uint256 packageId) external;

    /// @notice Refund all buyers if deal is cancelled
    /// @param packageId The loan package ID
    function refund(uint256 packageId) external;

    /// @notice Check if package is ready to settle
    /// @param packageId The loan package ID
    /// @return True if total USDC deposited >= sale price
    function canSettle(
        uint256 packageId
    ) external view returns (bool);
}
