import { z } from "zod";

// Address validation
export const addressSchema = z.string().regex(/^0x[a-fA-F0-9]{40}$/);

// Enums
export const userRole = z.enum(["buyer", "seller", "admin"]);
export const kycStatus = z.enum(["not_started", "pending", "approved", "rejected"]);
export const loanStatus = z.enum(["draft", "pending", "active", "closed", "defaulted"]);

// User
export const userSchema = z.object({
  id: z.string().uuid(),
  walletAddress: addressSchema,
  role: userRole,
  kycStatus: kycStatus,
  companyName: z.string().optional(),
  createdAt: z.date(),
});

// Pool
export const poolSchema = z.object({
  id: z.string().uuid(),
  onChainPoolId: z.number().int(),
  name: z.string(),
  description: z.string().optional(),
  ownerId: z.string().uuid(),
  assetSymbol: z.string(),
  createdAt: z.date(),
});

export const createPoolInput = z.object({
  onChainPoolId: z.number().int(),
  name: z.string().min(1).max(100),
  description: z.string().max(500).optional(),
  assetSymbol: z.string(),
});

// Loan
export const loanSchema = z.object({
  id: z.string().uuid(),
  poolId: z.string().uuid(),
  borrowerAddress: addressSchema,
  principal: z.string(), // BigInt as string
  interestRate: z.string(),
  termMonths: z.number().int().min(1).max(360),
  status: loanStatus,
  createdAt: z.date(),
});

export const createLoanInput = z.object({
  poolId: z.string().uuid(),
  borrowerAddress: addressSchema,
  principal: z.string(),
  interestRate: z.string(),
  termMonths: z.number().int().min(1).max(360),
  retentionRate: z.string(),
});
