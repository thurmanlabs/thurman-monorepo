import { z } from "zod";
import { router, publicProcedure, protectedProcedure } from "../trpc";
import { createLoanInput, loanStatus } from "../schemas";

export const loansRouter = router({
  // List loans by pool
  listByPool: publicProcedure
    .input(z.object({
      poolId: z.string().uuid(),
      status: loanStatus.optional(),
      limit: z.number().int().min(1).max(100).default(50),
    }))
    .query(async ({ input }) => {
      // TODO: Implement with database
      return {
        loans: [],
        nextCursor: null,
      };
    }),

  // Create draft loan (seller only)
  create: protectedProcedure
    .input(createLoanInput)
    .mutation(async ({ input, ctx }) => {
      if (ctx.user.role !== "seller") {
        throw new Error("Only sellers can create loans");
      }
      // TODO: Implement with database
      return {
        id: "temp-id",
        ...input,
        status: "draft" as const,
        createdAt: new Date(),
      };
    }),

  // Mark loans as submitted onchain
  markSubmitted: protectedProcedure
    .input(z.object({
      loanIds: z.array(z.string().uuid()),
      txHash: z.string(),
    }))
    .mutation(async ({ input, ctx }) => {
      // TODO: Implement with database
      return { success: true, count: input.loanIds.length };
    }),
});
