// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*//////////////////////////////////////////////////////////////
                    PLATFORM CONFIGURATION
//////////////////////////////////////////////////////////////*/

/// @title IPlatformConfig
/// @notice Platform-wide configuration settings
/// @dev Uses Arc's native USDC (18 decimals), no ERC-20 address needed
interface IPlatformConfig {
    // ═══════════════════════════════════════════════════════════════════════
    //                              ERRORS
    // ═══════════════════════════════════════════════════════════════════════

    error FeeTooHigh(uint256 requested, uint256 maximum);
    error ZeroAddress();
    error PlatformPaused();
    error PlatformNotPaused();
    error NotAuthorized(address account, bytes32 role);

    // ═══════════════════════════════════════════════════════════════════════
    //                              EVENTS
    // ═══════════════════════════════════════════════════════════════════════

    event PlatformFeeBpsUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FeeRecipientUpdated(address oldRecipient, address newRecipient);
    event Paused(address account);
    event Unpaused(address account);

    // ═══════════════════════════════════════════════════════════════════════
    //                          WRITE FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Set platform fee in basis points (e.g., 50 = 0.5%)
    /// @param feeBps Fee in basis points
    function setPlatformFeeBps(uint256 feeBps) external;

    /// @notice Get platform fee
    /// @return Fee in basis points
    function getPlatformFeeBps() external view returns (uint256);

    /// @notice Set fee recipient address
    /// @param recipient Address to receive platform fees
    function setFeeRecipient(address recipient) external;

    /// @notice Get fee recipient address
    /// @return Address that receives platform fees
    function getFeeRecipient() external view returns (address);

    /// @notice Pause the platform
    function pause() external;
    
    /// @notice Unpause the platform
    function unpause() external;
    
    /// @notice Check if platform is paused
    /// @return True if paused
    function isPaused() external view returns (bool);
}
