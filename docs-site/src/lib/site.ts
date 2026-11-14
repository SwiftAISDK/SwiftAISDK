export const sdkVersion: string = __SDK_VERSION__;
export const repositoryUrl = 'https://github.com/SwiftAISDK/SwiftAISDK';
export const releaseUrl = `${repositoryUrl}/releases/tag/${sdkVersion}`;

/** Prefixes a site-root path such as `/core/tools/` with the configured `base`. */
export function withBase(path: string): string {
  const base = import.meta.env.BASE_URL.replace(/\/$/, '');
  return `${base}${path.startsWith('/') ? path : `/${path}`}`;
}

/** Mirrors `llmsPagePath` in `scripts/generate-docs.mjs`. */
export function llmsPathForRoute(id: string): string {
  const slug = id.replace(/(^|\/)index$/, '').replace(/^\/|\/$/g, '');
  return slug ? `/llms/${slug}.txt` : '/llms/index.txt';
}
