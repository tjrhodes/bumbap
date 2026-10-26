import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";

// Relative paths, so the build works wherever it is served from (apps/vue/dist/ in the repo).
export default defineConfig({ plugins: [vue()], base: "./", build: { outDir: "dist" } });
