import { createTRPCRouter } from "./create-context";
import { recipeRouter } from "./routes/recipe";

export const appRouter = createTRPCRouter({
  recipe: recipeRouter,
});

export type AppRouter = typeof appRouter;
