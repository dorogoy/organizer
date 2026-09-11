## 2026-08-27 - Enhanced Authorization Header & Query Token Crash Sanitization

**Vulnerability:** HTTP Authorization headers formatted without the `Bearer` keyword (e.g. `Authorization: <token>`) or `access_token` query parameters could escape crash stack trace redaction if they didn't match standard `sk-` or `AIzaSy` secret prefixes.
**Learning:** Crash logging redaction pattern `_sensitivePatternString` previously matched `Authorization[:=]` only when optionally followed by `Bearer`, leaving un-prefixed authorization tokens exposed if they used custom token formats.
**Prevention:** Include flexible pattern matching for key-value delimiters (`[:=]`) and explicitly include common credential keys (`access_token`, `access-token`, `authorization`) across all stack trace sanitization regexes.
