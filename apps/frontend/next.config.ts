import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  // Minimal self-contained server for the container image
  output: 'standalone',
};

export default nextConfig;
