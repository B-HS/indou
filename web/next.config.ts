import type { NextConfig } from 'next'

// Static export for GitHub Pages, served from https://b-hs.github.io/indou/.
// basePath/assetPrefix prefix all assets with /indou so they resolve on the
// project page; images are unoptimized because there is no Next image server.
const nextConfig: NextConfig = {
    output: 'export',
    basePath: '/indou',
    trailingSlash: true,
    reactCompiler: true,
    images: {
        unoptimized: true,
    },
}

export default nextConfig
