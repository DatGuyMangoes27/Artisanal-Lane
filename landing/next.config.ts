import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  experimental: {
    // Vendor application photos are posted through a Server Action. The
    // framework default is 1 MB, which rejects ordinary phone photos before
    // the action can return a useful validation error.
    serverActions: {
      bodySizeLimit: "5mb",
    },
  },
  images: {
    unoptimized: true,
  },
  trailingSlash: true,
};

export default nextConfig;
