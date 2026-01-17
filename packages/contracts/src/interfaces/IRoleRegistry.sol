// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IRoleRegistry
/// @notice Interface for centralized role management across the Thurman Protocol
interface IRoleRegistry {
    // ═══════════════════════════════════════════════════════════════════════
    //                              ERRORS
    // ═══════════════════════════════════════════════════════════════════════

    error NotAdmin(address account);
    error ZeroAddress();
    error InvalidRole(bytes32 role);

    // ═══════════════════════════════════════════════════════════════════════
    //                              EVENTS
    // ═══════════════════════════════════════════════════════════════════════

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed grantor);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed revoker);

    // ═══════════════════════════════════════════════════════════════════════
    //                          WRITE FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Grants a role to an account
    /// @param role The role identifier
    /// @param account The address to grant the role to
    function grantRole(bytes32 role, address account) external;

    /// @notice Grants a role to multiple accounts
    /// @param role The role identifier
    /// @param accounts The addresses to grant the role to
    function grantRoleBatch(bytes32 role, address[] calldata accounts) external;

    /// @notice Revokes a role from an account
    /// @param role The role identifier
    /// @param account The address to revoke the role from
    function revokeRole(bytes32 role, address account) external;

    /// @notice Revokes a role from multiple accounts
    /// @param role The role identifier
    /// @param accounts The addresses to revoke the role from
    function revokeRoleBatch(bytes32 role, address[] calldata accounts) external;

    // ═══════════════════════════════════════════════════════════════════════
    //                          VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Checks if an account has a specific role
    /// @param role The role identifier
    /// @param account The address to check
    /// @return True if the account has the role
    function hasRole(bytes32 role, address account) external view returns (bool);

    /// @notice Returns all accounts with a specific role
    /// @param role The role identifier
    /// @return Array of addresses with the role
    function getRoleMembers(bytes32 role) external view returns (address[] memory);

    /// @notice Returns the number of accounts with a specific role
    /// @param role The role identifier
    /// @return Number of accounts with the role
    function getRoleMemberCount(bytes32 role) external view returns (uint256);
}
