import { z } from "zod";
import { router, publicProcedure, protectedProcedure } from "../trpc";
import { createPoolInput } from "../schemas";

export const poolsRouter = router({
  // List all pools
  list: publicProcedure
    .input(z.object({
      limit: z.number().int().min(1).max(50).default(20),
      cursor: z.string().optional(),
    }).optional())
    .query(async ({ input }) => {
      // TODO: Implement with database
      return {
        pools: [],
        nextCursor: null,
      };
    }),

  // Get pool by ID
  getById: publicProcedure
    .input(z.object({ id: z.string().uuid() }))
    .query(async ({ input }) => {
      // TODO: Implement with database
      return null;
    }),

  // Create pool (seller only)
  create: protectedProcedure
    .input(createPoolInput)
    .mutation(async ({ input, ctx }) => {
      if (ctx.user.role !== "seller") {
        throw new Error("Only sellers can create pools");
      }
      // TODO: Implement with database
      return {
        id: "temp-id",
        ...input,
        ownerId: ctx.user.id,
        createdAt: new Date(),
      };
    }),
});
