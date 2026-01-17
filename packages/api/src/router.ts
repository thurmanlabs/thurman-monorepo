import { router } from "./trpc";
import { authRouter } from "./routers/auth";
import { poolsRouter } from "./routers/pools";
import { loansRouter } from "./routers/loans";

export const appRouter = router({
  auth: authRouter,
  pools: poolsRouter,
  loans: loansRouter,
});

export type AppRouter = typeof appRouter;
