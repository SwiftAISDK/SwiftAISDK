import { defineConfig } from 'astro/config';
import { unified } from '@astrojs/markdown-remark';
import starlight from '@astrojs/starlight';
import remarkGfm from 'remark-gfm';
import { currentReleaseVersion } from './scripts/release-version.mjs';
import { markdownRoutes } from './scripts/markdown-routes.mjs';

const sdkVersion = currentReleaseVersion();

const base = process.env.DOCS_BASE ?? '/';
const site = process.env.DOCS_SITE ?? 'https://swiftaisdk.github.io';

export default defineConfig({
  site,
  base,
  // Preserve HTML-aware whitespace when upgrading from Astro 6.
  compressHTML: true,
  markdown: {
    processor: unified({ remarkPlugins: [remarkGfm] }),
  },
  vite: {
    define: { __SDK_VERSION__: JSON.stringify(sdkVersion) },
  },
  integrations: [
    markdownRoutes(),
    starlight({
      title: 'SwiftAISDK',
      description: 'SwiftPM port of the provider-facing Vercel AI SDK.',
      customCss: [
        '@fontsource-variable/geist',
        '@fontsource-variable/geist-mono',
        './src/styles/custom.css',
      ],
      components: {
        SiteTitle: './src/components/SiteTitle.astro',
        PageTitle: './src/components/PageTitle.astro',
        Hero: './src/components/Hero.astro',
      },
      expressiveCode: {
        themes: ['github-dark-default', 'github-light-default'],
        styleOverrides: {
          borderRadius: '10px',
          borderColor: 'var(--sl-color-hairline)',
          codeFontFamily: 'var(--sl-font-mono)',
          codeFontSize: '0.8125rem',
          codeLineHeight: '1.7',
          uiFontFamily: 'var(--sl-font)',
          frames: {
            shadowColor: 'transparent',
            editorActiveTabIndicatorTopColor: 'transparent',
            editorActiveTabIndicatorBottomColor: 'var(--sl-color-white)',
          },
        },
      },
      editLink: {
        baseUrl:
          'https://github.com/SwiftAISDK/SwiftAISDK/edit/main/docs-site/',
      },
      social: [
        {
          icon: 'github',
          label: 'GitHub',
          href: 'https://github.com/SwiftAISDK/SwiftAISDK',
        },
      ],
      sidebar: [
        {
          label: 'Start',
          items: [
            { label: 'Introduction', slug: '' },
            { label: 'Install', slug: 'getting-started/install' },
            { label: 'Quickstart', slug: 'getting-started/quickstart' },
            { label: 'Migrate to 3.0', slug: 'getting-started/migrating-to-3' },
          ],
        },
        {
          label: 'Text',
          items: [
            { label: 'Generate text', slug: 'core/generate-text' },
            { label: 'Stream text', slug: 'core/stream-text' },
            { label: 'Batches', slug: 'core/batch-text' },
            { label: 'Chat', slug: 'core/chat' },
          ],
        },
        {
          label: 'Structured data',
          items: [
            { label: 'Structured output', slug: 'core/structured-output' },
            { label: 'Extract fields', slug: 'core/extract' },
            { label: 'Decisions', slug: 'core/decide' },
            { label: 'Evaluation', slug: 'core/evaluate' },
          ],
        },
        {
          label: 'Tools and MCP',
          items: [
            { label: 'Tools', slug: 'core/tools' },
            { label: 'Agents', slug: 'core/agents' },
            { label: 'MCP tools', slug: 'cookbook/mcp-tools' },
            { label: 'MCP events', slug: 'cookbook/mcp-events' },
          ],
        },
        {
          label: 'Search',
          items: [
            { label: 'Embeddings', slug: 'core/embeddings' },
            { label: 'Rerank', slug: 'core/rerank' },
          ],
        },
        {
          label: 'Images and video',
          items: [
            { label: 'Generate image', slug: 'core/generate-image' },
            { label: 'Generate video', slug: 'core/generate-video' },
          ],
        },
        {
          label: 'Audio',
          items: [
            { label: 'Transcribe audio', slug: 'core/transcribe' },
            { label: 'Generate speech', slug: 'core/generate-speech' },
            { label: 'Stream speech', slug: 'core/stream-speech' },
            { label: 'Realtime sessions', slug: 'core/realtime' },
            { label: 'Generate audio', slug: 'core/generate-audio' },
            { label: 'Transform audio', slug: 'core/transform-audio' },
            { label: 'Dubbing', slug: 'core/dubbing' },
          ],
        },
        {
          label: 'Runtime',
          items: [
            { label: 'Model metadata', slug: 'core/model-metadata' },
            { label: 'Middleware', slug: 'core/middleware' },
            { label: 'Files', slug: 'core/files' },
            { label: 'Error handling', slug: 'core/error-handling' },
            { label: 'Telemetry', slug: 'core/telemetry' },
            { label: 'Troubleshooting', slug: 'troubleshooting' },
          ],
        },
        {
          label: 'Providers',
          collapsed: true,
          items: [{ autogenerate: { directory: 'providers' } }],
        },
        {
          label: 'Reference',
          collapsed: true,
          items: [
            {
              label: 'Public symbols',
              slug: 'reference/generated/public-symbols',
            },
            {
              label: 'API by component',
              collapsed: true,
              items: [{ autogenerate: { directory: 'components' } }],
            },
          ],
        },
      ],
    }),
  ],
});
