# Thurman Protocol API Plan

> MVP Backend API Contract for User Onboarding, Loan Management, and Pool Operations

## Overview

This document defines the backend API for Thurman's MVP, supporting:
- **Sellers (Originators)**: Onboard, register, add loans to pools
- **Buyers (LPs)**: Onboard, view pools/loans, make deposit offers

The API is designed to complement onchain contracts, handling off-chain data that's imprctical or impossible to store onchain.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Frontend (Next.js)                       │
├─────────────────────────────────────────────────────────────────┤
│  tRPC Client  │  Wagmi/viem (contract calls)                    │
└───────┬───────┴─────────────────────┬───────────────────────────┘
        │                             │
        ▼                             ▼
┌───────────────────┐      ┌─────────────────────────────────────┐
│   tRPC Router     │      │         Smart Contracts              │
│   (Next.js API)   │      │  PoolManager, ERC7540Vault, etc.    │
├───────────────────┤      └─────────────────────────────────────┘
│   Database        │
│   (Postgres)      │
└───────────────────┘
```

---

## Data Models (Zod Schemas)

### Core Enums

```typescript
// packages/api/src/schemas/enums.ts

export const UserRole = z.enum(["buyer", "seller", "admin"]);
export const KYCStatus = z.enum(["pending", "approved", "rejected", "not_started"]);
export const LoanStatus = z.enum(["draft", "pending_approval", "active", "closed", "defaulted"]);
export const OfferStatus = z.enum(["pending", "accepted", "rejected", "withdrawn"]);
```

### User Schema

```typescript
// packages/api/src/schemas/user.ts

export const userSchema = z.object({
  id: z.string().uuid(),
  walletAddress: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  email: z.string().email().optional(),
  role: UserRole,
  kycStatus: KYCStatus,
  
  // Seller-specific (nullable for buyers)
  companyName: z.string().optional(),
  originatorAddress: z.string().regex(/^0x[a-fA-F0-9]{40}$/).optional(), // On-chain registered address
  isRegisteredOriginator: z.boolean().default(false),
  
  createdAt: z.date(),
  updatedAt: z.date(),
});

export const createUserInput = z.object({
  walletAddress: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  role: UserRole,
  email: z.string().email().optional(),
  companyName: z.string().optional(),
});
```

### Pool Schema (Off-chain metadata)

```typescript
// packages/api/src/schemas/pool.ts

export const poolSchema = z.object({
  id: z.string().uuid(),
  onChainPoolId: z.number().int().min(0),          // Maps to contract poolId
  name: z.string().min(1).max(100),
  description: z.string().max(1000).optional(),
  
  // Owner/originator
  ownerId: z.string().uuid(),
  originatorAddress: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  
  // Asset info (denormalized from contract)
  assetAddress: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  assetSymbol: z.string(),                          // e.g., "USDC"
  assetDecimals: z.number().int().min(0).max(18),
  
  // Pool stats (indexed from chain)
  totalDeposits: z.string(),                        // BigInt as string
  totalLoans: z.number().int(),
  tvl: z.string(),                                  // Total Value Locked
  
  // Display metadata
  targetApy: z.string().optional(),                 // e.g., "8.5%"
  loanTypes: z.array(z.string()).optional(),        // e.g., ["auto", "personal"]
  
  createdAt: z.date(),
  updatedAt: z.date(),
});

export const createPoolInput = z.object({
  name: z.string().min(1).max(100),
  description: z.string().max(1000).optional(),
  assetAddress: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  targetApy: z.string().optional(),
  loanTypes: z.array(z.string()).optional(),
});
```

### Loan Schema (Off-chain staging + indexed on-chain data)

```typescript
// packages/api/src/schemas/loan.ts

// Aligns with Types.Loan from contracts
export const loanSchema = z.object({
  id: z.string().uuid(),
  
  // On-chain reference (null if draft/pending)
  onChainLoanId: z.number().int().optional(),
  poolId: z.string().uuid(),
  onChainPoolId: z.number().int(),
  
  // Core loan terms (matches contract Types.Loan)
  borrowerAddress: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  originatorAddress: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  principal: z.string(),                            // BigInt as string (uint128)
  interestRate: z.string(),                         // BigInt as string (WAD format)
  termMonths: z.number().int().min(1).max(360),
  retentionRate: z.string(),                        // Originator's retained interest
  
  // Status tracking
  status: LoanStatus,
  
  // Payment tracking (indexed from chain for active loans)
  currentPaymentIndex: z.number().int().optional(),
  remainingPrincipal: z.string().optional(),
  nextPaymentDate: z.date().optional(),
  
  // Off-chain metadata (not on contract)
  borrowerName: z.string().optional(),              // Anonymized/hashed for privacy
  loanType: z.string().optional(),                  // e.g., "auto", "personal", "mortgage"
  collateralDescription: z.string().optional(),
  
  createdAt: z.date(),
  updatedAt: z.date(),
});

// Input for sellers staging loans before on-chain submission
export const createLoanInput = z.object({
  poolId: z.string().uuid(),
  borrowerAddress: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  principal: z.string(),
  interestRate: z.string(),
  termMonths: z.number().int().min(1).max(360),
  retentionRate: z.string(),
  
  // Optional metadata
  borrowerName: z.string().optional(),
  loanType: z.string().optional(),
  collateralDescription: z.string().optional(),
});

// Batch loan input (matches Types.BatchLoanData)
export const batchLoanInput = z.object({
  poolId: z.string().uuid(),
  loans: z.array(createLoanInput).min(1).max(100),
});
```

### Offer Schema (Buyer deposit intents)

```typescript
// packages/api/src/schemas/offer.ts

export const offerSchema = z.object({
  id: z.string().uuid(),
  
  // Relationships
  poolId: z.string().uuid(),
  buyerId: z.string().uuid(),
  buyerAddress: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  
  // Offer details
  amount: z.string(),                               // Deposit amount (BigInt as string)
  status: OfferStatus,
  
  // On-chain tracking
  depositRequestTxHash: z.string().optional(),      // requestDeposit() tx
  fulfillmentTxHash: z.string().optional(),         // fulfillDeposit() tx
  
  // Timestamps
  expiresAt: z.date().optional(),
  createdAt: z.date(),
  updatedAt: z.date(),
});

export const createOfferInput = z.object({
  poolId: z.string().uuid(),
  amount: z.string(),
});
```

---

## API Routes (tRPC Procedures)

### Auth Router

```typescript
// packages/api/src/routers/auth.ts

export const authRouter = router({
  // Get or create user by wallet (called after wallet connect)
  getOrCreateUser: publicProcedure
    .input(z.object({
      walletAddress: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
    }))
    .mutation(async ({ input }) => {
      // Returns existing user or creates new one with role selection pending
    }),

  // Complete onboarding (set role, optional profile info)
  completeOnboarding: protectedProcedure
    .input(createUserInput)
    .mutation(async ({ input, ctx }) => {
      // Update user profile, set role
    }),

  // Get current user
  me: protectedProcedure
    .query(async ({ ctx }) => {
      return ctx.user;
    }),

  // Update profile
  updateProfile: protectedProcedure
    .input(z.object({
      email: z.string().email().optional(),
      companyName: z.string().optional(),
    }))
    .mutation(async ({ input, ctx }) => {
      // Update user profile
    }),
});
```

### Users Router

```typescript
// packages/api/src/routers/users.ts

export const usersRouter = router({
  // Get user by wallet address
  getByWallet: publicProcedure
    .input(z.object({ walletAddress: z.string() }))
    .query(async ({ input }) => {}),

  // List all sellers (for buyers to browse)
  listSellers: publicProcedure
    .input(z.object({
      kycStatus: KYCStatus.optional(),
      limit: z.number().int().min(1).max(100).default(20),
      cursor: z.string().optional(),
    }))
    .query(async ({ input }) => {}),

  // Admin: Update KYC status
  updateKycStatus: adminProcedure
    .input(z.object({
      userId: z.string().uuid(),
      status: KYCStatus,
    }))
    .mutation(async ({ input }) => {}),
});
```

### Pools Router

```typescript
// packages/api/src/routers/pools.ts

export const poolsRouter = router({
  // List all pools (for buyers)
  list: publicProcedure
    .input(z.object({
      assetSymbol: z.string().optional(),           // Filter by asset
      originatorId: z.string().uuid().optional(),   // Filter by seller
      limit: z.number().int().min(1).max(50).default(20),
      cursor: z.string().optional(),
    }))
    .query(async ({ input }) => {}),

  // Get single pool with stats
  getById: publicProcedure
    .input(z.object({ id: z.string().uuid() }))
    .query(async ({ input }) => {}),

  // Get pool by on-chain ID
  getByOnChainId: publicProcedure
    .input(z.object({ onChainPoolId: z.number().int() }))
    .query(async ({ input }) => {}),

  // Create pool metadata (seller only, after on-chain pool creation)
  create: sellerProcedure
    .input(createPoolInput.extend({
      onChainPoolId: z.number().int(),
    }))
    .mutation(async ({ input, ctx }) => {}),

  // Update pool metadata
  update: sellerProcedure
    .input(z.object({
      id: z.string().uuid(),
      name: z.string().optional(),
      description: z.string().optional(),
      targetApy: z.string().optional(),
    }))
    .mutation(async ({ input, ctx }) => {
      // Verify ownership before update
    }),

  // Get pools owned by current seller
  myPools: sellerProcedure
    .query(async ({ ctx }) => {}),
});
```

### Loans Router

```typescript
// packages/api/src/routers/loans.ts

export const loansRouter = router({
  // List loans in a pool (for buyers viewing)
  listByPool: publicProcedure
    .input(z.object({
      poolId: z.string().uuid(),
      status: LoanStatus.optional(),
      limit: z.number().int().min(1).max(100).default(50),
      cursor: z.string().optional(),
    }))
    .query(async ({ input }) => {}),

  // Get single loan details
  getById: publicProcedure
    .input(z.object({ id: z.string().uuid() }))
    .query(async ({ input }) => {}),

  // Create draft loan (seller staging before on-chain)
  create: sellerProcedure
    .input(createLoanInput)
    .mutation(async ({ input, ctx }) => {
      // Validate seller owns the pool
      // Create loan with status: "draft"
    }),

  // Create batch of draft loans
  createBatch: sellerProcedure
    .input(batchLoanInput)
    .mutation(async ({ input, ctx }) => {
      // Validate seller owns the pool
      // Create multiple loans with status: "draft"
    }),

  // Submit loans for on-chain initialization
  // Called after seller signs batchInitLoan transaction
  markSubmitted: sellerProcedure
    .input(z.object({
      loanIds: z.array(z.string().uuid()),
      txHash: z.string(),
    }))
    .mutation(async ({ input, ctx }) => {
      // Update status to "pending_approval"
      // Store txHash for tracking
    }),

  // Webhook/indexer: Mark loans as active after on-chain confirmation
  confirmOnChain: internalProcedure
    .input(z.object({
      loanIds: z.array(z.string().uuid()),
      onChainLoanIds: z.array(z.number().int()),
    }))
    .mutation(async ({ input }) => {
      // Update status to "active"
      // Link on-chain loan IDs
    }),

  // Get loans created by current seller
  myLoans: sellerProcedure
    .input(z.object({
      poolId: z.string().uuid().optional(),
      status: LoanStatus.optional(),
    }))
    .query(async ({ input, ctx }) => {}),

  // Get loan stats for a pool
  getPoolStats: publicProcedure
    .input(z.object({ poolId: z.string().uuid() }))
    .query(async ({ input }) => {
      // Return aggregate stats: total principal, avg interest rate, etc.
    }),
});
```

### Offers Router

```typescript
// packages/api/src/routers/offers.ts

export const offersRouter = router({
  // Create deposit offer (buyer intent)
  create: buyerProcedure
    .input(createOfferInput)
    .mutation(async ({ input, ctx }) => {
      // Create offer with status: "pending"
    }),

  // Update offer after on-chain requestDeposit()
  markRequested: buyerProcedure
    .input(z.object({
      offerId: z.string().uuid(),
      txHash: z.string(),
    }))
    .mutation(async ({ input, ctx }) => {}),

  // Withdraw offer
  withdraw: buyerProcedure
    .input(z.object({ offerId: z.string().uuid() }))
    .mutation(async ({ input, ctx }) => {}),

  // Get offers by buyer
  myOffers: buyerProcedure
    .input(z.object({
      poolId: z.string().uuid().optional(),
      status: OfferStatus.optional(),
    }))
    .query(async ({ input, ctx }) => {}),

  // Get offers for a pool (seller view)
  listByPool: sellerProcedure
    .input(z.object({
      poolId: z.string().uuid(),
      status: OfferStatus.optional(),
    }))
    .query(async ({ input, ctx }) => {
      // Verify seller owns pool
    }),

  // Accept offer (seller triggers fulfillDeposit)
  accept: sellerProcedure
    .input(z.object({
      offerId: z.string().uuid(),
      txHash: z.string(),
    }))
    .mutation(async ({ input, ctx }) => {}),

  // Reject offer
  reject: sellerProcedure
    .input(z.object({ offerId: z.string().uuid() }))
    .mutation(async ({ input, ctx }) => {}),
});
```

---

## Full Router Export

```typescript
// packages/api/src/router.ts

import { router } from './trpc';
import { authRouter } from './routers/auth';
import { usersRouter } from './routers/users';
import { poolsRouter } from './routers/pools';
import { loansRouter } from './routers/loans';
import { offersRouter } from './routers/offers';

export const appRouter = router({
  auth: authRouter,
  users: usersRouter,
  pools: poolsRouter,
  loans: loansRouter,
  offers: offersRouter,
});

export type AppRouter = typeof appRouter;
```

---

## User Flows

### Seller (Originator) Flow

```
1. Connect Wallet
   └─▶ auth.getOrCreateUser({ walletAddress })

2. Complete Onboarding
   └─▶ auth.completeOnboarding({ role: "seller", companyName, ... })

3. Register as Originator (on-chain)
   └─▶ OriginatorRegistry.registerOriginator() [contract call]
   └─▶ Indexed automatically

4. Create Pool (on-chain first)
   └─▶ PoolManager.addPool() [contract call]
   └─▶ pools.create({ onChainPoolId, name, description, ... })

5. Add Loans to Pool
   └─▶ loans.create({ poolId, borrowerAddress, principal, ... })  [draft]
   └─▶ loans.createBatch({ poolId, loans: [...] })                [batch draft]
   
6. Submit Loans On-Chain
   └─▶ PoolManager.batchInitLoan() [contract call]
   └─▶ loans.markSubmitted({ loanIds, txHash })

7. View & Accept Offers
   └─▶ offers.listByPool({ poolId })
   └─▶ offers.accept({ offerId, txHash })  [after fulfillDeposit]
```

### Buyer (LP) Flow

```
1. Connect Wallet
   └─▶ auth.getOrCreateUser({ walletAddress })

2. Complete Onboarding
   └─▶ auth.completeOnboarding({ role: "buyer", ... })

3. Browse Pools
   └─▶ pools.list({ assetSymbol: "USDC" })
   └─▶ pools.getById({ id })

4. View Loans in Pool
   └─▶ loans.listByPool({ poolId, status: "active" })
   └─▶ loans.getPoolStats({ poolId })

5. Make Deposit Offer
   └─▶ offers.create({ poolId, amount })
   └─▶ PoolManager.requestDeposit() [contract call]
   └─▶ offers.markRequested({ offerId, txHash })

6. Track Offer Status
   └─▶ offers.myOffers({ status: "pending" })

7. Claim Shares (after acceptance)
   └─▶ ERC7540Vault.deposit() [contract call]
```

---

## Database Schema (Prisma)

```prisma
// packages/db/prisma/schema.prisma

model User {
  id                    String    @id @default(uuid())
  walletAddress         String    @unique
  email                 String?
  role                  UserRole
  kycStatus             KYCStatus @default(NOT_STARTED)
  companyName           String?
  originatorAddress     String?
  isRegisteredOriginator Boolean  @default(false)
  
  pools                 Pool[]
  offers                Offer[]
  
  createdAt             DateTime  @default(now())
  updatedAt             DateTime  @updatedAt
}

model Pool {
  id                String   @id @default(uuid())
  onChainPoolId     Int      @unique
  name              String
  description       String?
  
  ownerId           String
  owner             User     @relation(fields: [ownerId], references: [id])
  originatorAddress String
  
  assetAddress      String
  assetSymbol       String
  assetDecimals     Int
  
  // Indexed stats (updated by indexer)
  totalDeposits     String   @default("0")
  totalLoans        Int      @default(0)
  tvl               String   @default("0")
  
  targetApy         String?
  loanTypes         String[] @default([])
  
  loans             Loan[]
  offers            Offer[]
  
  createdAt         DateTime @default(now())
  updatedAt         DateTime @updatedAt
}

model Loan {
  id                  String     @id @default(uuid())
  onChainLoanId       Int?
  
  poolId              String
  pool                Pool       @relation(fields: [poolId], references: [id])
  onChainPoolId       Int
  
  borrowerAddress     String
  originatorAddress   String
  principal           String
  interestRate        String
  termMonths          Int
  retentionRate       String
  
  status              LoanStatus @default(DRAFT)
  
  currentPaymentIndex Int?
  remainingPrincipal  String?
  nextPaymentDate     DateTime?
  
  borrowerName        String?
  loanType            String?
  collateralDescription String?
  
  submissionTxHash    String?
  
  createdAt           DateTime   @default(now())
  updatedAt           DateTime   @updatedAt
  
  @@index([poolId, status])
  @@index([originatorAddress])
}

model Offer {
  id                  String      @id @default(uuid())
  
  poolId              String
  pool                Pool        @relation(fields: [poolId], references: [id])
  buyerId             String
  buyer               User        @relation(fields: [buyerId], references: [id])
  buyerAddress        String
  
  amount              String
  status              OfferStatus @default(PENDING)
  
  depositRequestTxHash String?
  fulfillmentTxHash    String?
  
  expiresAt           DateTime?
  createdAt           DateTime    @default(now())
  updatedAt           DateTime    @updatedAt
  
  @@index([poolId, status])
  @@index([buyerId])
}

enum UserRole {
  BUYER
  SELLER
  ADMIN
}

enum KYCStatus {
  NOT_STARTED
  PENDING
  APPROVED
  REJECTED
}

enum LoanStatus {
  DRAFT
  PENDING_APPROVAL
  ACTIVE
  CLOSED
  DEFAULTED
}

enum OfferStatus {
  PENDING
  ACCEPTED
  REJECTED
  WITHDRAWN
}
```

---

## Next Steps

1. **Set up packages/api** with tRPC + Zod
2. **Set up packages/db** with Prisma + Postgres
3. **Implement auth** with SIWE (Sign-In with Ethereum)
4. **Build indexer** to sync onchain events to database
5. **Wire up to apps/web** via tRPC client

---

## Contract Alignment Reference

| API Entity | Contract Struct | Notes |
|------------|-----------------|-------|
| `Loan` | `Types.Loan` | Offchain adds metadata (borrowerName, loanType) |
| `Pool` | `Types.Pool` | Offchain adds display info (name, description) |
| `Offer` | N/A | Pure offchain intent tracking |
| `User` | `OriginatorRegistry` | Sellers map to registered originators |

| API Operation | Contract Function |
|---------------|-------------------|
| `loans.create` (batch) → submit | `PoolManager.batchInitLoan()` |
| `offers.create` → onchain | `PoolManager.requestDeposit()` |
| `offers.accept` | `PoolManager.fulfillDeposit()` |
