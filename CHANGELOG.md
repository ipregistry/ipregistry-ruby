# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-07-04
### Added
- Initial release of the official Ruby client library for the Ipregistry API.
- `Client#lookup` for single IP address lookups, `Client#lookup_origin` for origin (requester) lookups returning
  parsed User-Agent data, and `Client#batch_lookup` for resolving many IP addresses at once. Batch lookups
  transparently split arrays larger than the API's 1024-address limit into concurrently dispatched sub-requests
  (configurable via `max_batch_size:` and `batch_concurrency:`) and reassemble results in input order.
- `Client#parse_user_agents` for parsing raw User-Agent strings into structured data.
- Batch results (`BatchResponse`) expose per-entry success or failure through `Result` objects, are `Enumerable`,
  and support pattern matching.
- Nil-safe response models: nested sections are always present, so chained access such as
  `info.location.country.name` never raises; boolean fields are exposed as predicates (`security.vpn?`).
- Optional in-memory caching (`Cache::Memory`) with LRU eviction and TTL, plus a duck-typed interface for custom
  backends. Caching is disabled by default; origin lookups are never cached and batch lookups reuse cached entries.
- Automatic retries with exponential backoff for transient network errors and 5xx responses, honoring the
  `Retry-After` header. Retries on 429 Too Many Requests are disabled by default.
- Typed errors rooted at `Ipregistry::Error`: every documented API error code maps to a dedicated `ApiError`
  subclass (e.g. `InvalidApiKeyError`, `InsufficientCreditsError`), and client-side failures raise
  `ConnectionError`, `TimeoutError`, or `ParseError`.
- `Ipregistry.bot?` helper to skip lookups for crawler traffic.
- Offline unit/behavior specs using WebMock, plus opt-in live system specs in `spec/system` (run with
  `IPREGISTRY_API_KEY` set).
- Zero runtime dependencies (standard library only).

[Unreleased]: https://github.com/ipregistry/ipregistry-ruby/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/ipregistry/ipregistry-ruby/releases/tag/v1.0.0
