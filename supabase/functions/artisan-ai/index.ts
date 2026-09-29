import { createHandler } from "./core.ts";
Deno.serve(createHandler((name) => Deno.env.get(name)));
