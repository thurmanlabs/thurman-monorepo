import { z } from "zod";
import { router, publicProcedure, protectedProcedure } from "../trpc";
import { addressSchema, userRole } from "../schemas";

export const authRouter = router({
  // Get or create user on wallet connect
  getOrCreateUser: publicProcedure
    .input(z.object({ walletAddress: addressSchema }))
    .mutation(async ({ input }) => {
      // TODO: Implement with database
      return {
        id: "temp-id",
        walletAddress: input.walletAddress,
        role: null,
        isNewUser: true,
      };
    }),

  // Complete onboarding
  completeOnboarding: publicProcedure
    .input(z.object({
      walletAddress: addressSchema,
      role: userRole,
      companyName: z.string().optional(),
    }))
    .mutation(async ({ input }) => {
      // TODO: Implement with database
      return {
        id: "temp-id",
        walletAddress: input.walletAddress,
        role: input.role,
        companyName: input.companyName,
      };
    }),

  // Get current user
  me: protectedProcedure.query(async ({ ctx }) => {
    return ctx.user;
  }),
});
