import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// Relative paths, so the build works wherever it is served from (apps/react/dist/ in the repo).
export default defineConfig({ plugins: [react()], base: "./", build: { outDir: "dist" } });
