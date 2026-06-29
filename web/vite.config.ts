import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// `base` defaults to '/' for local dev and most hosts. For a GitHub Pages
// project site the app is served from /<repo>/, so the Pages workflow sets
// VITE_BASE=/blackbookproject/ at build time.
export default defineConfig({
  base: process.env.VITE_BASE ?? '/',
  plugins: [react()],
  server: { port: 5173 },
});
