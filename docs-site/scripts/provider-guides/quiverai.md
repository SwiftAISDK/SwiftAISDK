## Portable reasoning

QuiverAI supports `low`, `medium`, `high`, and `xhigh`. Portable `none` and `minimal` map to `low`; `max` maps to `xhigh`, with compatibility warnings in generation and stream-start metadata. Explicit canonical provider `reasoningEffort` retains precedence and bypasses portable mapping.

## Rotating credentials

`QuiverAIProviderSettings.apiKeyProvider` accepts an async throwing key supplier resolved before each authenticated language or image request. Static keys remain available; provider/request authorization headers keep their precedence, and supplier failures stop the request before I/O.
