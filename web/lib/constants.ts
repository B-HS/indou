export const REPO_URL = 'https://github.com/B-HS/indou'
export const RELEASE_URL = 'https://github.com/B-HS/indou/releases/latest'

// GitHub Pages project path. next/image doesn't prefix basePath onto static
// public assets in `output: 'export'`, so reference assets via `${BASE_PATH}/…`.
export const BASE_PATH = '/indou'
export const asset = (path: string) => `${BASE_PATH}${path}`
