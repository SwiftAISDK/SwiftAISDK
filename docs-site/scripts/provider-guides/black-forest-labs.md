## FLUX 3 image inputs

Official/signed external image downloads retain the versioned/custom user-agent while omitting provider authentication and request credentials. Same-origin custom proxies retain configured headers. Official polling remains authenticated. Image input capability discovery recognizes FLUX 3.

`flux-3-image` supports up to ten reference images, 768sq/1k/1.5k/2k/4k resolution, grounding, the latest version and safety tolerance 0–7. Size can derive an aspect ratio; explicit aspect ratio wins. Seed and unsupported legacy fields warn and are omitted; masks fail before submission. Polling recognizes pending/reasoning/generating states and terminates on failed, moderated or missing tasks.

`flux-3-image-klein` and unknown future image IDs use the latest image API. They accept up to ten references, seed, PNG/JPEG output, 1–16 steps and safety tolerance 0–7. `size` sends exact dimensions without a warning; provider `width`/`height` override it. Both dimensions must be supplied, each from 64 through 6256, with at most 16,822,272 total pixels. Explicit dimensions take precedence over aspect ratio and resolution. Grounding, version and legacy input options are omitted with warnings; masks are unsupported. Known FLUX 1/2 and Kontext IDs keep their existing protocol.
