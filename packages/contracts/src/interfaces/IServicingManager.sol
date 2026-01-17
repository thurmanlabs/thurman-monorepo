// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*//////////////////////////////////////////////////////////////
                    SERVICING & PAYMENT DISTRIBUTION
//////////////////////////////////////////////////////////////*/

/// @title IServicingManager
/// @notice Handles payment recording and pro-rata distribution to token holders
/// @dev Uses Arc's native USDC (18 decimals) for payments via msg.value
interface IServicingManager {
    // ═══════════════════════════════════════════════════════════════════════
    //                              ERRORS
    // ═══════════════════════════════════════════════════════════════════════

    error PackageNotActive(uint256 packageId);
    error PaymentMismatch(uint256 expected, uint256 received);
    error ZeroPayment();
    error TransferFailed(address to, uint256 amount);
    error NotPackageSeller(address caller, address seller);
    error NoSnapshots(uint256 packageId);

    // ═══════════════════════════════════════════════════════════════════════
    //                              EVENTS
    // ═══════════════════════════════════════════════════════════════════════

    event PaymentRecorded(
        uint256 indexed packageId,
        uint256 principalAmount,
        uint256 interestAmount,
        bytes32 servicingDataHash,
        uint256 timestamp
    );

    event PaymentDistributed(
        uint256 indexed packageId,
        address indexed holder,
        uint256 amount
    );

    // ═══════════════════════════════════════════════════════════════════════
    //                              TYPES
    // ═══════════════════════════════════════════════════════════════════════

    struct ServicingSnapshot {
        uint256 timestamp;
        uint256 principalCollected;
        uint256 interestCollected;
        uint256 principalOutstanding;
        bytes32 servicingDataHash;  // Hash of servicing CSV
    }

    /// @notice Seller records a payment and distributes to token holders
    /// @param packageId The loan package receiving payment
    /// @param principalAmount Principal portion of payment (must match msg.value breakdown)
    /// @param interestAmount Interest portion of payment (must match msg.value breakdown)
    /// @param servicingDataHash Hash of the servicing CSV file
    /// @dev Send native USDC via msg.value (18 decimals), must equal principalAmount + interestAmount
    /// @dev Auto-distributes pro-rata to all token holders
    function recordPayment(
        uint256 packageId,
        uint256 principalAmount,
        uint256 interestAmount,
        bytes32 servicingDataHash
    ) external payable;

    /// @notice Get latest servicing snapshot
    /// @param packageId The loan package ID
    /// @return Latest ServicingSnapshot
    function getLatestSnapshot(
        uint256 packageId
    ) external view returns (ServicingSnapshot memory);

    /// @notice Get all snapshots for a package
    /// @param packageId The loan package ID
    /// @return Array of all ServicingSnapshots
    function getSnapshots(
        uint256 packageId
    ) external view returns (ServicingSnapshot[] memory);

    /// @notice Get total principal collected for a package
    /// @param packageId The loan package ID
    /// @return Total principal collected to date
    function getTotalPrincipalCollected(
        uint256 packageId
    ) external view returns (uint256);

    /// @notice Get total interest collected for a package
    /// @param packageId The loan package ID
    /// @return Total interest collected to date
    function getTotalInterestCollected(
        uint256 packageId
    ) external view returns (uint256);

    /// @notice Calculate pro-rata distribution for a token holder
    /// @param packageId The loan package ID
    /// @param holder The token holder address
    /// @param paymentAmount The total payment amount to distribute
    /// @return Amount this holder would receive
    function calculateDistribution(
        uint256 packageId,
        address holder,
        uint256 paymentAmount
    ) external view returns (uint256);
}
