# Thurman Protocol

A secondary market for CDFIs to sell loan packages to buyers on-chain using native USDC on Arc.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        THURMAN PROTOCOL (6 Contracts)                       │
└─────────────────────────────────────────────────────────────────────────────┘

    ┌──────────┐                                              ┌──────────┐
    │  Seller  │                                              │  Buyers  │
    │  (CDFI)  │                                              │  (LPs)   │
    └────┬─────┘                                              └────┬─────┘
         │                                                         │
         │ 1. createPackage()                                      │
         ├──────────────────────┐                                  │
         │                      ▼                                  │
         │           ┌────────────────────┐                        │
         │           │    LoanPackage     │                        │
         │           │     (ERC1155)      │                        │
         │           │  + PackageMetadata │                        │
         │           └──────────┬─────────┘                        │
         │                      │                                  │
         │ 2. depositTokens()   │                                  │
         ├──────────────────────│                                  │
         │                      ▼                                  │
         │             ┌─────────────────┐                         │
         │             │   DvP Escrow    │◄────────────────────────│ 3. depositUSDC{value: X}
         │             └────────┬────────┘                         │
         │                      │                                  │
         │          ┌───────────┴───────────┐                      │
         │          │     4. settle()       │                      │
         │          │   (atomic DvP swap)   │                      │
         │          └───────────┬───────────┘                      │
         │                      │                                  │
         │◄─────────────────────└──────────────────────────────────►
         │   USDC to seller                   tokens to buyers     │
         │                                                         │
         │                                                         │
         │ 5. recordPayment()  ┌──────────────────┐                │
         └────────────────────►│ ServicingManager │────────────────►
                               └──────────────────┘   6. distribute
                                                      USDC pro-rata

┌─────────────────────────────────────────────────────────────────────────────┐
│                            SUPPORTING CONTRACTS                             │
├─────────────────────────────────────────────────────────────────────────────┤
│  RoleRegistry    │  PlatformConfig  │  ThurmanBase     │  ThurmanRoles      │
│  (role mgmt)     │  (fees, pause)   │  (shared base)   │  (role constants)  │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Contracts

| Contract | Description |
|----------|-------------|
| **LoanPackage** | ERC1155 token + package metadata. Single source of truth for ownership and package details. |
| **DvPEscrow** | Delivery-vs-payment settlement. Holds buyer USDC until atomic swap. |
| **ServicingManager** | Records payments from seller, auto-distributes pro-rata to token holders. |
| **PlatformConfig** | Platform fees, pause functionality. |
| **RoleRegistry** | Centralized role management (ADMIN, SELLER, BUYER, MINTER roles). |
| **ThurmanBase** | Abstract base contract with shared modifiers (`whenNotPaused`, `onlyRole`). |

## Roles

| Role | Permissions |
|------|-------------|
| `ADMIN_ROLE` | Platform configuration, pause, fee settings, settle deals, mark defaults |
| `SELLER_ROLE` | Create packages, deposit tokens, record payments |
| `BUYER_ROLE` | Deposit USDC to purchase packages |
| `MINTER_ROLE` | Mint tokens (granted to DvPEscrow contract) |

## Package Lifecycle

```
Created ───► Escrowed ───► Settled ───► Active ───► Closed
                │                         │
                └── (refund) ─────────────┴───► Defaulted
```

| Status | Description |
|--------|-------------|
| `Created` | Package registered, awaiting token escrow |
| `Escrowed` | Tokens in escrow, awaiting buyer USDC |
| `Settled` | DvP complete, tokens distributed to buyers |
| `Active` | Collecting servicing payments |
| `Closed` | All loans paid off |
| `Defaulted` | Package experienced default |

## Key Design Decisions

### On-Chain vs Off-Chain

| On-Chain | Off-Chain |
|----------|-----------|
| Token ownership | Loan tape (CSV) |
| Native USDC transfers | Amortization schedules |
| Package status | Servicing calculations |
| Payment distribution | Individual loan tracking |
| Hash proofs (`loanTapeHash`, `servicingDataHash`) | Borrower data |

### Why This Architecture?

1. **Package-centric model** — Matches how loan sales work (pools/tapes)
2. **Off-chain computation, on-chain settlement** — Servicing math stays off-chain, hashes provide auditability
3. **Simple DvP escrow** — Atomic swap, not complex async vault flows
4. **ERC1155 tokens** — Perfect for fractional ownership of multiple packages
5. **Non-transferable tokens** — Tokens are ownership receipts, transfers are disabled
6. **Native USDC** — Uses Arc's native USDC (18 decimals) via `msg.value`, not ERC-20
7. **Centralized role registry** — Single source of truth for access control across all contracts

## Usage Flow

### For Sellers (CDFIs)

```solidity
// 1. Create a loan package (returns auto-generated packageId)
uint256 packageId = loanPackage.createPackage(
    100_000,                       // 100k tokens
    100_000 * 1e18,                // $100k native USDC (18 decimals)
    loanTapeHash,                  // Hash of loan CSV
    "Q1 Manufacturing Fund",
    "50 small business loans"
);

// 2. Escrow tokens for sale
dvpEscrow.depositTokens(packageId, 100_000);

// 3. After settlement, record servicing payments (send native USDC)
servicingManager.recordPayment{value: paymentAmount}(
    packageId,
    principalAmount,
    interestAmount,
    servicingDataHash
);
```

### For Buyers (LPs)

```solidity
// 1. Deposit native USDC to buy into package (no approval needed)
dvpEscrow.depositUSDC{value: amount}(packageId);

// 2. After settlement, receive tokens automatically
// 3. Receive pro-rata native USDC distributions from servicing
```

### For Admins

```solidity
// Grant roles
roleRegistry.grantRole(ThurmanRoles.SELLER_ROLE, cdfiAddress);
roleRegistry.grantRole(ThurmanRoles.BUYER_ROLE, buyerAddress);

// Settle a deal when fully funded
dvpEscrow.settle(packageId);

// Activate package for servicing
loanPackage.updateStatus(packageId, ILoanPackage.PackageStatus.Active);

// If needed, refund buyers
dvpEscrow.refund(packageId);

// Mark package as defaulted
loanPackage.markDefaulted(packageId);
```

## Interfaces

All interfaces are defined in `src/interfaces/`:

- `ILoanPackage` — ERC1155 + metadata + lifecycle
- `IDvPEscrow` — Settlement mechanics
- `IServicingManager` — Payment distribution
- `IPlatformConfig` — System configuration
- `IRoleRegistry` — Role management

## Development

```bash
# Build contracts and generate ABIs
pnpm build

# Test
pnpm test

# Or using forge directly
forge build
forge test

# Generate TypeScript ABIs only
pnpm generate-abis
```

## Project Structure

```
src/
├── interfaces/           # Contract interfaces
│   ├── IDvPEscrow.sol
│   ├── ILoanPackage.sol
│   ├── IPlatformConfig.sol
│   ├── IRoleRegistry.sol
│   └── IServicingManager.sol
├── abi/                  # Generated TypeScript ABIs
├── DvPEscrow.sol         # DvP settlement
├── LoanPackage.sol       # ERC1155 + metadata
├── PlatformConfig.sol    # Platform settings
├── RoleRegistry.sol      # Access control
├── ServicingManager.sol  # Payment distribution
├── ThurmanBase.sol       # Shared modifiers
└── ThurmanRoles.sol      # Role constants
```

## License

MIT
