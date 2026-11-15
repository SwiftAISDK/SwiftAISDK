## Signed approval replay

The executable-tool `AI.streamText` overloads accept an explicit
`toolApprovalSecret:` alongside `toolApproval:`. Use the same application secret
that signed the original approval. Streaming checks signatures before executing
historical approvals, including tampered-signature rejection. Existing overloads
retain their previous unsigned behavior.

Replay validates the saved schema input, applies refinement once, and verifies
that it produces the approved operation. Execution uses that verified input;
a mismatch becomes an error tool result and does not execute the tool.
