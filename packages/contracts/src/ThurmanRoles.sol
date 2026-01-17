// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ThurmanRoles
/// @notice Shared role constants for the Thurman Protocol
/// @dev Import this file to use consistent role definitions across all contracts
library ThurmanRoles {
    /// @notice Admin role - platform configuration, pause, fee settings, settle deals
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Seller role - create packages, record payments
    bytes32 public constant SELLER_ROLE = keccak256("SELLER_ROLE");

    /// @notice Buyer role - deposit USDC to purchase packages
    bytes32 public constant BUYER_ROLE = keccak256("BUYER_ROLE");

    /// @notice Minter role - mint tokens (granted to DvPEscrow contract)
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
}
