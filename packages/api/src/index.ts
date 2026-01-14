export { appRouter, type AppRouter } from "./router";
export { type Context } from "./trpc";
export * from "./schemas";

// Re-export for convenience
export { router, publicProcedure, protectedProcedure } from "./trpc";
