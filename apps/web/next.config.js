/** @type {import('next').NextConfig} */
const nextConfig = {
  transpilePackages: ["@repo/ui", "@repo/contracts"],
  output: "standalone",
};

export default nextConfig;
