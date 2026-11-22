# Provider Capability Matrix

Snapshot date: 2026-11-22

This document and `AIProviderCapabilities` are generated from
`Porting/packages.json`. Update the catalog, then run
`node Scripts/sdk.mjs generate`; runtime tests still verify actual coverage.

Legend:

- `L`: language
- `C`: completion
- `E`: embedding
- `I`: image
- `T`: transcription
- `S`: speech
- `AG`: audio generation
- `AT`: audio transformation
- `D`: dubbing
- `V`: video
- `R`: reranking
- `EV`: evaluation
- `DC`: decision
- `EX`: extraction
- `F`: file upload client
- `K`: skill upload client

| Upstream package | Provider ID | Swift factories | L | C | E | I | T | S | AG | AT | D | V | R | EV | DC | EX | F | K |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `@ai-sdk/alibaba` | `alibaba` | `AIProviders.alibaba` | ✅ |  | ✅ |  |  |  |  |  |  | ✅ |  |  |  |  |  |  |
| `@ai-sdk/amazon-bedrock` | `amazon-bedrock` | `AIProviders.amazonBedrock` | ✅ |  | ✅ | ✅ |  |  |  |  |  |  | ✅ |  |  |  |  |  |
| `@ai-sdk/amazon-bedrock` | `amazon-bedrock.anthropic` | `AIProviders.amazonBedrockAnthropic` | ✅ |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| `@ai-sdk/amazon-bedrock` | `bedrock-mantle` | `AIProviders.bedrockMantle` | ✅ |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| `@ai-sdk/anthropic` | `anthropic` | `AIProviders.anthropic` | ✅ |  |  |  |  |  |  |  |  |  |  | ✅ | ✅ | ✅ | ✅ | ✅ |
| `@ai-sdk/anthropic-aws` | `anthropic-aws` | `AIProviders.anthropicAWS` | ✅ |  |  |  |  |  |  |  |  |  |  |  |  |  | ✅ | ✅ |
| `@ai-sdk/assemblyai` | `assemblyai` | `AIProviders.assemblyAI` |  |  |  |  | ✅ | ✅ |  |  |  |  |  |  |  |  |  |  |
| `@ai-sdk/azure` | `azure` | `AIProviders.azure` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |  |  |  |  |  |  |  |  |
| `@ai-sdk/baseten` | `baseten` | `AIProviders.baseten` | ✅ |  | ✅ |  |  |  |  |  |  |  |  |  |  |  |  |  |
| `@ai-sdk/black-forest-labs` | `black-forest-labs` | `AIProviders.blackForestLabs` |  |  |  | ✅ |  |  |  |  |  | ✅ |  |  |  |  |  |  |
| `@ai-sdk/bytedance` | `bytedance` | `AIProviders.byteDance` |  |  |  | ✅ |  |  |  |  |  | ✅ |  |  |  |  |  |  |
| `@ai-sdk/cartesia` | `cartesia` | `AIProviders.cartesia` |  |  |  |  | ✅ | ✅ |  |  |  |  |  |  |  |  |  |  |
| `@ai-sdk/cerebras` | `cerebras` | `AIProviders.cerebras` | ✅ |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| `@ai-sdk/cohere` | `cohere` | `AIProviders.cohere` | ✅ |  | ✅ |  |  |  |  |  |  |  | ✅ |  |  |  |  |  |
| `@ai-sdk/deepgram` | `deepgram` | `AIProviders.deepgram` |  |  |  |  | ✅ | ✅ |  |  |  |  |  |  |  |  |  |  |
| `@ai-sdk/deepinfra` | `deepinfra` | `AIProviders.deepInfra` | ✅ | ✅ | ✅ | ✅ |  |  |  |  |  |  |  |  |  |  |  |  |
| `@ai-sdk/deepseek` | `deepseek` | `AIProviders.deepSeek` | ✅ |  |  |  |  |  |  |  |  |  |  |  |  |  | ✅ |  |
| `@ai-sdk/elevenlabs` | `elevenlabs` | `AIProviders.elevenLabs` |  |  |  |  | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |  |  |  |  |  |
| `@ai-sdk/fal` | `fal` | `AIProviders.fal` |  |  |  | ✅ | ✅ | ✅ |  |  |  | ✅ |  |  |  |  |  |  |
| `@ai-sdk/fish-audio` | `fish-audio` | `AIProviders.fishAudio` |  |  |  |  | ✅ | ✅ |  |  |  |  |  |  |  |  |  |  |
| `@ai-sdk/fireworks` | `fireworks` | `AIProviders.fireworks` | ✅ | ✅ | ✅ | ✅ |  |  |  |  |  |  |  |  |  |  |  |  |
| `@ai-sdk/gateway` | `gateway` | `AIProviders.gateway` | ✅ |  | ✅ | ✅ | ✅ | ✅ |  |  |  | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `@ai-sdk/gmicloud` | `gmicloud` | `AIProviders.gmiCloud` | ✅ |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| `@ai-sdk/gladia` | `gladia` | `AIProviders.gladia` |  |  |  |  | ✅ |  |  |  |  |  |  |  |  |  |  |  |
| `@ai-sdk/google` | `google.generative-ai` | `AIProviders.google` | ✅ |  | ✅ | ✅ |  | ✅ |  |  |  | ✅ |  | ✅ | ✅ | ✅ | ✅ |  |
| `@ai-sdk/google-vertex` | `google.vertex` | `AIProviders.googleVertex` | ✅ |  | ✅ | ✅ | ✅ | ✅ |  |  |  | ✅ |  |  |  |  |  |  |
| `@ai-sdk/google-vertex` | `googleVertex.maas` | `AIProviders.googleVertexMaaS` | ✅ | ✅ | ✅ | ✅ |  |  |  |  |  |  |  |  |  |  |  |  |
| `@ai-sdk/google-vertex` | `googleVertex.xai` | `AIProviders.googleVertexXAI` | ✅ |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| `@ai-sdk/google-vertex` | `googleVertex.anthropic` | `AIProviders.googleVertexAnthropic` | ✅ |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| `@ai-sdk/groq` | `groq` | `AIProviders.groq` | ✅ |  |  |  | ✅ |  |  |  |  |  |  |  |  |  |  |  |
| `@ai-sdk/heygen` | `heygen` | `AIProviders.heyGen`, `createHeyGen`, `heygen` |  |  |  |  |  |  |  |  |  | ✅ |  |  | ✅ |  |  |  |
| `@ai-sdk/huggingface` | `huggingface` | `AIProviders.huggingFace` | ✅ |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| `@ai-sdk/hume` | `hume` | `AIProviders.hume` |  |  |  |  |  | ✅ |  |  |  |  |  |  |  |  |  |  |
| `@ai-sdk/klingai` | `klingai` | `AIProviders.klingAI` |  |  |  |  |  |  |  |  |  | ✅ |  |  |  |  |  |  |
| `@ai-sdk/lmnt` | `lmnt` | `AIProviders.lmnt` |  |  |  |  |  | ✅ |  |  |  |  |  |  |  |  |  |  |
| `@ai-sdk/luma` | `luma` | `AIProviders.luma` |  |  |  | ✅ |  |  |  |  |  |  |  |  |  |  |  |  |
| `@ai-sdk/minimax` | `minimax` | `AIProviders.miniMax` | ✅ |  |  | ✅ |  |  |  |  |  | ✅ |  |  |  |  |  |  |
| `@ai-sdk/mistral` | `mistral` | `AIProviders.mistral` | ✅ |  | ✅ |  | ✅ | ✅ |  |  |  |  |  |  |  |  |  |  |
| `@ai-sdk/moonshotai` | `moonshotai` | `AIProviders.moonshotAI` | ✅ |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| `@ai-sdk/open-responses` | `open-responses.responses` | `AIProviders.openResponses` | ✅ |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| `@ai-sdk/openai` | `openai` | `AIProviders.openAI` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |  |  |  | ✅ | ✅ | ✅ | ✅ | ✅ |
| `@ai-sdk/openai-compatible` | `openai-compatible` | `AIProviders.openAICompatible` | ✅ | ✅ | ✅ | ✅ |  |  |  |  |  |  |  |  |  |  |  |  |
| `@ai-sdk/perplexity` | `perplexity` | `AIProviders.perplexity` | ✅ |  | ✅ |  |  |  |  |  |  |  |  |  | ✅ |  |  |  |
| `@ai-sdk/prodia` | `prodia` | `AIProviders.prodia` | ✅ |  |  | ✅ |  |  |  |  |  | ✅ |  |  |  |  |  |  |
| `@ai-sdk/quiverai` | `quiverai` | `AIProviders.quiverAI` | ✅ |  |  | ✅ |  |  |  |  |  |  |  |  |  |  |  |  |
| `@ai-sdk/replicate` | `replicate` | `AIProviders.replicate` |  |  |  | ✅ |  |  |  |  |  | ✅ |  |  |  |  |  |  |
| `@ai-sdk/revai` | `revai` | `AIProviders.revAI` |  |  |  |  | ✅ |  |  |  |  |  |  |  |  |  |  |  |
| `@ai-sdk/togetherai` | `togetherai` | `AIProviders.togetherAI` | ✅ | ✅ | ✅ | ✅ |  |  |  |  |  |  | ✅ |  |  |  |  |  |
| `@ai-sdk/topaz` | `topaz` | `AIProviders.topaz` |  |  |  | ✅ |  |  |  |  |  | ✅ |  |  |  |  |  |  |
| `@ai-sdk/typesafe-ai` | `typesafe` | `AIProviders.typeSafeAI` |  |  |  |  |  |  |  |  |  |  |  | ✅ | ✅ |  |  |  |
| `@ai-sdk/vercel` | `vercel` | `AIProviders.vercel` | ✅ |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| `@ai-sdk/voyage` | `voyage` | `AIProviders.voyage` |  |  | ✅ |  |  |  |  |  |  |  | ✅ |  |  |  |  |  |
| `@ai-sdk/xai` | `xai` | `AIProviders.xAI` | ✅ |  |  | ✅ | ✅ | ✅ |  |  |  | ✅ |  |  |  |  | ✅ |  |
| `@ai-sdk/zai` | `zai` | `AIProviders.zai` | ✅ |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| `@ai-sdk/parallel` | `parallel` | `AIProviders.parallel`, `createParallel`, `parallel` |  |  |  |  |  |  |  |  |  |  |  |  | ✅ |  |  |  |
| `@ai-sdk/scaledown` | `scaledown` | `AIProviders.scaleDown` |  |  |  |  |  |  |  |  |  |  |  |  | ✅ | ✅ |  |  |
| `@ai-sdk/tencent` | `tencent` | `AIProviders.tencent` | ✅ |  |  |  |  |  |  |  |  | ✅ |  |  |  |  |  |  |
| `@ai-sdk/liquid` | `liquid` | `AIProviders.liquid`, `createLiquid`, `liquid` |  |  |  |  |  |  |  |  |  |  |  |  | ✅ |  |  |  |

## Provider Notes

| Provider ID | Note |
| --- | --- |
| `alibaba` | Qwen chat models, DashScope text embeddings and Wan video generation through Alibaba Cloud's international DashScope endpoint. Supports thinking controls, JSON Schema output on newer Qwen models, and asynchronous video tasks that are polled until completion. |
| `amazon-bedrock` | Foundation models on Amazon Bedrock through the Converse API, plus Titan, Cohere and Nova embeddings, Nova Canvas images and Bedrock reranking. Authenticate with a Bedrock API key or AWS SigV4 credentials; the AWS SDK credential chain is not used, so supply credentials through settings, a credential provider closure or environment variables. |
| `amazon-bedrock.anthropic` | Claude models on Amazon Bedrock called through InvokeModel in Anthropic's native Messages format, so Anthropic provider options and tool definitions carry over. It shares settings and authentication with the Amazon Bedrock provider. |
| `bedrock-mantle` | OpenAI-compatible Chat Completions and Responses endpoints on Amazon Bedrock Mantle, authenticated with a Bedrock API key or SigV4 credentials. The endpoint path is chosen from the model ID. |
| `anthropic` | Claude models through the Anthropic Messages API, with thinking, prompt caching, citations, Anthropic-hosted tools, message threads, files, skills and message batches. Decision, evaluation and extraction models run over Messages with structured output. |
| `anthropic-aws` | Claude models through Anthropic's Claude Platform on AWS, authenticated with an Anthropic AWS API key or AWS SigV4 credentials and scoped to a workspace. It uses the same Messages adapter as the Anthropic provider, including message threads, files and skills. |
| `assemblyai` | AssemblyAI file transcription with timed words and automatic language detection, plus buffered Speech V4 for MP3 and PCM output. |
| `azure` | OpenAI models deployed on Azure, using the Responses API by default plus Chat, completions, embeddings, images, transcription and speech, addressed by deployment name. Authenticate with an API key or a Microsoft Entra ID token provider; MAI Voice, MAI Transcribe and MAI Image models use their Azure-specific APIs. |
| `baseten` | Chat models on Baseten Model APIs or on your own dedicated deployment, plus embeddings from dedicated deployments. Set `modelURL` to target a deployment; embeddings always require a `/sync` or `/sync/v1` model URL. |
| `black-forest-labs` | FLUX image generation and editing and FLUX 3 video generation from Black Forest Labs. Jobs are submitted and polled until the result is ready; the request protocol and available options depend on the model family. |
| `bytedance` | Seedance video generation and Seedream image generation through BytePlus ModelArk. Video comes from text, first and last frames or reference media; tasks are polled until the video is ready, or run as resumable start/status operations. |
| `cartesia` | Sonic text-to-speech, Ink Whisper batch transcription and Ink 2 streaming transcription over WebSocket. Streaming transcription uses `streamingTranscriptionModel`; batch transcription only accepts Ink Whisper models. |
| `cerebras` | Fast chat completions on Cerebras inference hardware, with reasoning effort, service tiers and queue thresholds, structured outputs and tool calling. |
| `cohere` | Command chat models with reasoning, document grounding and citations, plus Embed models (float, integer and binary vectors) and Rerank models, through Cohere's v2 API. |
| `deepgram` | Deepgram speech-to-text (Nova models), real-time streaming transcription over WebSocket and Aura text-to-speech for Swift apps. |
| `deepinfra` | Open-weight chat, completion and embedding models through DeepInfra's OpenAI-compatible API, plus image generation and editing. Structured output is enabled for chat models, and image models return one image per call. |
| `deepseek` | DeepSeek chat and reasoning models with thinking controls, tool calling, vision input on supported models and the DeepSeek Files API. The native provider also offers the Responses API with built-in web search. |
| `elevenlabs` | ElevenLabs text-to-speech (including WebSocket streaming and multi-speaker dialogue) and Scribe speech-to-text. The provider also exposes music, sound effects, voice changer, voice isolator and dubbing. |
| `fal` | Image generation and editing, queued video generation, speech and transcription on fal's hosted model endpoints. Video and transcription jobs are polled to completion, and video can also complete through fal webhooks. |
| `fish-audio` | Fish Audio text-to-speech with reference voices, latency and sampling controls, plus speech-to-text with timed segments. |
| `fireworks` | Open-weight chat, completion and embedding models on Fireworks AI with thinking and prompt-cache controls, plus FLUX and Stable Diffusion image generation. Asynchronous Kontext image jobs are polled to completion. |
| `gateway` | One provider for hundreds of models from many vendors through the Vercel AI Gateway: text, embeddings, images, video, speech, transcription, reranking, decisions, realtime and batches. It adds routing and fallback controls, Gateway-executed search tools and account APIs for credits and spend. Includes native Extraction V4 and continuous Realtime Live alongside the turn-based route. |
| `gmicloud` | Open-weight chat models such as Kimi, GLM, DeepSeek and MiniMax through GMI Cloud's OpenAI-compatible API, with streaming usage and tool calls. Only language models are available. |
| `gladia` | Gladia pre-recorded speech-to-text with diarization, translation, PII redaction and other add-ons. Jobs are uploaded and polled to completion, and remote audio URLs can be transcribed without uploading. |
| `google.generative-ai` | Gemini models through the Gemini API (Google AI Studio): text with thinking, tools and Google Search grounding, embeddings, Gemini and Imagen images, TTS speech, Veo video, files, decisions, extraction, Gemini Live realtime and batches. For Gemini on Google Cloud, use the Google Vertex AI provider. |
| `google.vertex` | Gemini language, embedding, image, speech, transcription and Veo video models on Google Cloud Vertex AI. Authenticate with an Express Mode API key, an OAuth access token, or a service account; OAuth and service accounts also need a project and location. |
| `googleVertex.maas` | Open models from Vertex AI Model Garden, such as Llama, through Vertex's OpenAI-compatible endpoint for chat, completion, embedding and image models. Authenticates with an OAuth access token. |
| `googleVertex.xai` | xAI Grok language models hosted on Vertex AI through its OpenAI-compatible Chat Completions endpoint. Authenticates with an OAuth access token; reasoning_effort is removed from requests. |
| `googleVertex.anthropic` | Anthropic Claude models hosted on Vertex AI through rawPredict, with the shared Anthropic options, tools and thinking support. Authenticates with an OAuth access token and supports Vertex billing labels. |
| `groq` | Low-latency chat models on Groq, including GPT-OSS and Qwen reasoning models with tool calling, structured output and built-in browser search, plus Whisper transcription. |
| `heygen` | HeyGen asynchronous video generation from text, a first-frame image or image, video and audio references, with resumable jobs, plus multimodal decisions. Videos are returned as signed MP4 URLs. |
| `huggingface` | Open models through the Hugging Face inference router's Responses API, with function tools, reasoning, structured output and image input. Only language models are available. |
| `hume` | Expressive text-to-speech from Hume's TTS API. One speech model, no model ID required; acting directions come from instructions, and earlier generations can be passed as context. |
| `klingai` | Kling video generation: text-to-video, image-to-video, multi-image reference video and motion control, selected by the model ID suffix. Jobs are polled until the MP4 URL is ready. |
| `lmnt` | LMNT text-to-speech models such as aurora and blizzard, returning MP3, AAC, WAV, mu-law or raw audio. Speech models always need a model ID. |
| `luma` | Luma Photon image generation (photon-1, photon-flash-1) with image, style, character and modify-image references. Generation is asynchronous: the model polls until the image is ready and returns both the URL and the image data. |
| `minimax` | MiniMax M-series language models through an Anthropic-compatible Messages API, plus H3 image generation and editing and H3 video generation. M3.1 and later models add reasoning effort, image and video input, and prompt caching. |
| `mistral` | Mistral chat, Conversations API with hosted web search, embeddings, Voxtral speech and Voxtral transcription. Streaming transcription and managed voice sessions are available on the native MistralProvider. |
| `moonshotai` | Moonshot Kimi and moonshot-v1 chat models through Moonshot's Chat Completions API, with structured output, thinking and reasoning-effort controls, prompt caching and image or video input. |
| `open-responses.responses` | Connects to any server that implements the Open Responses specification (an open version of the OpenAI Responses API) at a URL you provide. No environment variables are read; pass an API key or headers in settings. |
| `openai` | OpenAI Responses and Chat Completions language models with hosted tools, plus embeddings, images, speech, transcription, Decisions, extraction, files, skills, batch and Live realtime sessions. languageModel uses the Responses API; use chatModel for Chat Completions. |
| `openai-compatible` | Connects to any server that implements OpenAI's Chat Completions, Completions, Embeddings and Images endpoints, using a name and base URL you supply. No environment variables are read; pass an API key or headers when creating the provider. |
| `perplexity` | Perplexity web-grounded language models through the Agent API and the Sonar Chat Completions API, plus quantized embeddings and native Decisions. `languageModel` uses the Agent API; use `sonarModel` for Sonar. |
| `prodia` | Prodia image, video and image-capable language jobs submitted to the Prodia v2 job API. Model IDs are Prodia job types such as `inference.flux-fast.schnell.txt2img.v2`. |
| `quiverai` | QuiverAI Arrow models for SVG generation, vectorization, animation and editing, plus Arrow language models over the Responses API. Image results are SVG documents returned as base64-encoded markup. |
| `replicate` | Image and video generation with models hosted on Replicate, addressed as `owner/model` or `owner/model:version`. The SDK waits for and polls predictions and downloads image outputs. |
| `revai` | Asynchronous speech-to-text with Rev.ai. Each transcription submits a job, polls until it completes and returns the transcript with timed segments. |
| `togetherai` | Open-weight chat, completion and embedding models, FLUX and other image models, and reranking through Together AI's OpenAI-compatible API. Streams include usage by default. |
| `topaz` | Topaz Labs image and video enhancement: upscale and restore an existing image with Wonder, or enhance a video with Proteus or Starlight as a resumable job. Topaz does not generate media from text. |
| `typesafe` | TypeSafe AI decision models for Choice, Score, Boolean and image Box questions over text, JSON and PNG/JPEG evidence. Answers are rounded to two decimals and include confidence metadata. |
| `vercel` | Vercel's v0 models, such as `v0-1.5-md`, through the OpenAI-compatible v0 Model API. Only language models are available. |
| `voyage` | Voyage AI text embeddings, including general, code and domain models, and document reranking. Embedding calls accept up to 128 inputs each. |
| `xai` | xAI Grok language models over the Responses API with hosted web, X and code tools, plus Grok Imagine image and video generation, speech, batch and streaming transcription, files, batch text and realtime voice sessions. |
| `zai` | Z.AI GLM chat models, such as `glm-5.3`, with thinking and reasoning controls over Z.AI's OpenAI-compatible endpoint. Only language models are available. |
| `parallel` | Parallel's web-grounded decision models answer Boolean, Choice and Score questions with shared web citations and confidence. Parallel offers decisions only; there are no text, media or embedding models. |
| `scaledown` | ScaleDown classification decisions (Choice, Boolean and Score) and text extraction over text, JSON and one JPEG, PNG, TIFF or PDF document. Extraction supports text fields and lists of text only. |
| `tencent` | Tencent TokenHub chat models and Kling video generation, plus Tencent Cloud VOD video generation with TC3-signed requests. Both backends expose resumable video jobs, and each backend loads its own credentials only when used. |
| `liquid` | Liquid native Decision V4 handles choice, score, boolean and box questions with text, JSON, image and audio evidence. Returns full-precision probabilities, confidence, score legends, token usage and cost. |

## Reality Gates

Use three gates when judging provider completeness:

1. The provider appears in `AIProviderCapabilities.all`.
2. Unit tests cover the request and response or stream shape for every
   supported capability in the matrix.
3. At least one opt-in live smoke test exists for representative
   providers and can be run with real keys.

The live smoke suite is intentionally off by default. Run it with:

```sh
LIVE_AI_TESTS=1 swift test --filter LiveProviderSmoke
```

The suite reads `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`,
`DEEPSEEK_API_KEY`, `ASSEMBLYAI_API_KEY`, `ELEVENLABS_API_KEY`,
`CARTESIA_API_KEY`,
and `OPENAI_COMPATIBLE_API_KEY`.
When running from Xcode, set them as test environment variables in the
scheme instead of Run/Profile arguments.
Override model IDs with
`LIVE_OPENAI_MODEL`, `LIVE_ANTHROPIC_MODEL`, `LIVE_GOOGLE_MODEL`,
`LIVE_DEEPSEEK_MODEL`, `LIVE_ASSEMBLYAI_MODEL`, `LIVE_OPENAI_COMPATIBLE_MODEL`,
`LIVE_OPENAI_COMPATIBLE_BASE_URL`, `LIVE_ELEVENLABS_SPEECH_MODEL`,
`LIVE_ELEVENLABS_TRANSCRIPTION_MODEL`, `LIVE_ELEVENLABS_VOICE`,
`LIVE_CARTESIA_SPEECH_MODEL`, `LIVE_CARTESIA_TRANSCRIPTION_MODEL`,
and `LIVE_CARTESIA_VOICE`.
It covers text generation, text streaming, executable generate/stream tool loops,
OpenAI-compatible generation/streaming/completion/tool loops/object generation,
AssemblyAI transcription, ElevenLabs speech/transcription/audio generation/audio
transformation/dubbing, Cartesia speech/batch transcription, and representative embeddings.
Embedding checks also read
`LIVE_OPENAI_EMBEDDING_MODEL` and `LIVE_GOOGLE_EMBEDDING_MODEL`.
