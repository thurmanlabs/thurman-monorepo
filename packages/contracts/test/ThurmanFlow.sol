// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Test } from "forge-std/Test.sol";

import { RoleRegistry } from "../src/RoleRegistry.sol";
import { PlatformConfig } from "../src/PlatformConfig.sol";
import { LoanPackage } from "../src/LoanPackage.sol";
import { ILoanPackage } from "../src/interfaces/ILoanPackage.sol";
import { DvPEscrow } from "../src/DvPEscrow.sol";
import { ServicingManager } from "../src/ServicingManager.sol";
import { ThurmanRoles } from "../src/ThurmanRoles.sol";

contract ThurmanFlowTest is Test {
    address owner;
    address seller;
    address buyer1;
    address buyer2;
    RoleRegistry roleRegistry;
    PlatformConfig platformConfig;
    LoanPackage loanPackage;

    function setUp() public {
        owner = makeAddr("owner");
        seller = makeAddr("seller");
        buyer1 = makeAddr("buyer1");
        buyer2 = makeAddr("buyer2");

        vm.startPrank(owner);

        roleRegistry = new RoleRegistry(owner, owner); // ownber is initial admin for testing
        platformConfig = new PlatformConfig(owner, address(roleRegistry), owner, 50);
        loanPackage = new LoanPackage(owner, address(platformConfig), address(roleRegistry));

        // set seller and buyer roles
        roleRegistry.grantRole(ThurmanRoles.SELLER_ROLE, seller);
        roleRegistry.grantRole(ThurmanRoles.BUYER_ROLE, buyer1);
        roleRegistry.grantRole(ThurmanRoles.BUYER_ROLE, buyer2);

        vm.stopPrank();
    }

    function testCreateLoan() public {
        vm.prank(seller);
        uint256 packageId = loanPackage.createPackage(100, 100, ILoanPackage.PackageType.Package, "loanTapeHash", "packageName", "description");
        assertEq(packageId, 0); // First package gets ID 0
        assertEq(uint8(loanPackage.getPackage(packageId).status), uint8(ILoanPackage.PackageStatus.Created));
    }
}