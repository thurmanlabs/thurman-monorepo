// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IRoleRegistry } from "./interfaces/IRoleRegistry.sol";
import { IPlatformConfig } from "./interfaces/IPlatformConfig.sol";
import { ThurmanRoles } from "./ThurmanRoles.sol";

/// @title ThurmanBase
/// @notice Abstract base contract with shared modifiers for Thurman Protocol contracts
abstract contract ThurmanBase {
    // ═══════════════════════════════════════════════════════════════════════
    //                              STATE
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Platform configuration contract
    IPlatformConfig public immutable platformConfig;

    /// @notice Role registry contract
    IRoleRegistry public immutable roleRegistry;

    // ═══════════════════════════════════════════════════════════════════════
    //                              ERRORS
    // ═══════════════════════════════════════════════════════════════════════

    error PlatformPaused();
    error NotAuthorized(address account, bytes32 role);
    error ZeroAddress();

    // ═══════════════════════════════════════════════════════════════════════
    //                            CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════════

    constructor(address platformConfig_, address roleRegistry_) {
        if (platformConfig_ == address(0)) revert ZeroAddress();
        if (roleRegistry_ == address(0)) revert ZeroAddress();

        platformConfig = IPlatformConfig(platformConfig_);
        roleRegistry = IRoleRegistry(roleRegistry_);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                              MODIFIERS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Reverts if platform is paused
    modifier whenNotPaused() {
        _whenNotPaused();
        _;
    }

    function _whenNotPaused() internal view {
        if (platformConfig.isPaused()) revert PlatformPaused();
    }

    /// @notice Reverts if caller doesn't have the specified role or is not an admin
    modifier onlyRole(bytes32 role) {
        _onlyRole(role);
        _;
    }

    function _onlyRole(bytes32 role) internal view {
        if (!roleRegistry.hasRole(role, msg.sender) && !roleRegistry.hasRole(ThurmanRoles.ADMIN_ROLE, msg.sender)) {
            revert NotAuthorized(msg.sender, role);
        }
    }
}
