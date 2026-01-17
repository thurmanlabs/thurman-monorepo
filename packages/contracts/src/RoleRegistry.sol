// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { IRoleRegistry } from "./interfaces/IRoleRegistry.sol";
import { ThurmanRoles } from "./ThurmanRoles.sol";

/// @title RoleRegistry
/// @notice Centralized role management for the Thurman Protocol
/// @dev Single source of truth for SELLER, BUYER, and MINTER roles
contract RoleRegistry is IRoleRegistry, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    // ═══════════════════════════════════════════════════════════════════════
    //                              STATE
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Role members by role identifier
    mapping(bytes32 => EnumerableSet.AddressSet) private _roleMembers;

    // ═══════════════════════════════════════════════════════════════════════
    //                            CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════════

    /// @param owner_ Address to set as contract owner
    /// @param admin Initial admin address
    constructor(address owner_, address admin) Ownable(owner_) {
        if (admin == address(0)) revert ZeroAddress();

        _roleMembers[ThurmanRoles.ADMIN_ROLE].add(admin);
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
        if (!_roleMembers[ThurmanRoles.ADMIN_ROLE].contains(msg.sender)) {
            revert NotAdmin(msg.sender);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                         ROLE MANAGEMENT
    // ═══════════════════════════════════════════════════════════════════════

    /// @inheritdoc IRoleRegistry
    function grantRole(bytes32 role, address account) external onlyAdmin {
        if (account == address(0)) revert ZeroAddress();
        _validateRole(role);

        if (_roleMembers[role].add(account)) {
            emit RoleGranted(role, account, msg.sender);
        }
    }

    /// @inheritdoc IRoleRegistry
    function grantRoleBatch(bytes32 role, address[] calldata accounts) external onlyAdmin {
        _validateRole(role);

        for (uint256 i = 0; i < accounts.length; i++) {
            if (accounts[i] == address(0)) revert ZeroAddress();
            if (_roleMembers[role].add(accounts[i])) {
                emit RoleGranted(role, accounts[i], msg.sender);
            }
        }
    }

    /// @inheritdoc IRoleRegistry
    function revokeRole(bytes32 role, address account) external onlyAdmin {
        _validateRole(role);

        if (_roleMembers[role].remove(account)) {
            emit RoleRevoked(role, account, msg.sender);
        }
    }

    /// @inheritdoc IRoleRegistry
    function revokeRoleBatch(bytes32 role, address[] calldata accounts) external onlyAdmin {
        _validateRole(role);

        for (uint256 i = 0; i < accounts.length; i++) {
            if (_roleMembers[role].remove(accounts[i])) {
                emit RoleRevoked(role, accounts[i], msg.sender);
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                          VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// @inheritdoc IRoleRegistry
    function hasRole(bytes32 role, address account) external view returns (bool) {
        return _roleMembers[role].contains(account);
    }

    /// @inheritdoc IRoleRegistry
    function getRoleMembers(bytes32 role) external view returns (address[] memory) {
        return _roleMembers[role].values();
    }

    /// @inheritdoc IRoleRegistry
    function getRoleMemberCount(bytes32 role) external view returns (uint256) {
        return _roleMembers[role].length();
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                         INTERNAL FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Validates that a role is a known Thurman role
    /// @param role The role to validate
    function _validateRole(bytes32 role) internal pure {
        if (
            role != ThurmanRoles.ADMIN_ROLE &&
            role != ThurmanRoles.SELLER_ROLE &&
            role != ThurmanRoles.BUYER_ROLE &&
            role != ThurmanRoles.MINTER_ROLE
        ) {
            revert InvalidRole(role);
        }
    }
}
