## Per-video media types

`VideoGenerationResult.videoURLDescriptors` preserves each generated URL and its
media type when a provider returns mixed formats. Tencent fills these descriptors
for TokenHub and VOD results, including MOV, MP4 and WebM. Multi-operation video
generation preserves the associations while merging results. Existing `urls`,
common `mediaType` and initializer signatures remain available. An empty descriptor
array means the provider exposes the existing common-media-type result.
