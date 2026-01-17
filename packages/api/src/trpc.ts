import { initTRPC } from "@trpc/server";
import superjson from "superjson";

export type Context = {
  user?: {
    id: string;
    walletAddress: string;
    role: "buyer" | "seller" | "admin";
  };
};

const t = initTRPC.context<Context>().create({
  transformer: superjson,
});

export const router = t.router;
export const publicProcedure = t.procedure;

// Protected procedure - requires authenticated user
export const protectedProcedure = t.procedure.use(({ ctx, next }) => {
  if (!ctx.user) {
    throw new Error("Not authenticated");
  }
  return next({ ctx: { ...ctx, user: ctx.user } });
});
