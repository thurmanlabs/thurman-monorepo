// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { IPlatformConfig } from "./interfaces/IPlatformConfig.sol";
import { IRoleRegistry } from "./interfaces/IRoleRegistry.sol";
import { ThurmanRoles } from "./ThurmanRoles.sol";

/// @title PlatformConfig
/// @notice Platform-wide configuration for the Thurman Protocol
/// @dev Uses Arc's native USDC (18 decimals), no ERC-20 address needed
contract PlatformConfig is IPlatformConfig, Ownable {
    // ═══════════════════════════════════════════════════════════════════════
    //                              STATE
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Role registry contract
    IRoleRegistry public immutable roleRegistry;

    /// @notice Platform fee in basis points (e.g., 50 = 0.5%)
    uint256 private _platformFeeBps;

    /// @notice Address that receives platform fees
    address private _feeRecipient;

    /// @notice Whether the platform is paused
    bool private _paused;

    // ═══════════════════════════════════════════════════════════════════════
    //                              CONSTANTS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Maximum fee in basis points (10% = 1000 bps)
    uint256 public constant MAX_FEE_BPS = 1000;

    // ═══════════════════════════════════════════════════════════════════════
    //                            CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════════

    /// @param owner_ Address to set as contract owner
    /// @param roleRegistry_ Role registry contract address
    /// @param feeRecipient_ Initial fee recipient address
    /// @param initialFeeBps Initial platform fee in basis points
    constructor(
        address owner_,
        address roleRegistry_,
        address feeRecipient_,
        uint256 initialFeeBps
    ) Ownable(owner_) {
        if (roleRegistry_ == address(0)) revert ZeroAddress();
        if (feeRecipient_ == address(0)) revert ZeroAddress();
        if (initialFeeBps > MAX_FEE_BPS) revert FeeTooHigh(initialFeeBps, MAX_FEE_BPS);

        roleRegistry = IRoleRegistry(roleRegistry_);
        _feeRecipient = feeRecipient_;
        _platformFeeBps = initialFeeBps;
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                              MODIFIERS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Reverts if caller is not an admin
    modifier onlyAdmin() {
        _onlyAdmin();
        _;
    }

    function _onlyAdmin() internal view {
        if (!roleRegistry.hasRole(ThurmanRoles.ADMIN_ROLE, msg.sender)) {
            revert NotAuthorized(msg.sender, ThurmanRoles.ADMIN_ROLE);
        }
    }

    /// @notice Reverts if platform is paused
    modifier whenNotPaused() {
        _whenNotPaused();
        _;
    }

    function _whenNotPaused() internal view {
        if (_paused) revert PlatformPaused();
    }

    /// @notice Reverts if platform is not paused
    modifier whenPaused() {
        _whenPaused();
        _;
    }

    function _whenPaused() internal view {
        if (!_paused) revert PlatformNotPaused();
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                          ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// @inheritdoc IPlatformConfig
    function setPlatformFeeBps(uint256 feeBps) external onlyAdmin {
        if (feeBps > MAX_FEE_BPS) revert FeeTooHigh(feeBps, MAX_FEE_BPS);
        
        uint256 oldFeeBps = _platformFeeBps;
        _platformFeeBps = feeBps;
        
        emit PlatformFeeBpsUpdated(oldFeeBps, feeBps);
    }

    /// @inheritdoc IPlatformConfig
    function setFeeRecipient(address recipient) external onlyAdmin {
        if (recipient == address(0)) revert ZeroAddress();
        
        address oldRecipient = _feeRecipient;
        _feeRecipient = recipient;
        
        emit FeeRecipientUpdated(oldRecipient, recipient);
    }

    /// @inheritdoc IPlatformConfig
    function pause() external onlyAdmin whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    /// @inheritdoc IPlatformConfig
    function unpause() external onlyAdmin whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                          VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// @inheritdoc IPlatformConfig
    function getPlatformFeeBps() external view returns (uint256) {
        return _platformFeeBps;
    }

    /// @inheritdoc IPlatformConfig
    function getFeeRecipient() external view returns (address) {
        return _feeRecipient;
    }

    /// @inheritdoc IPlatformConfig
    function isPaused() external view returns (bool) {
        return _paused;
    }
}
