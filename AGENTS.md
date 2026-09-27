# AGENTS.md

Compact guide for OpenCode sessions. Every line answers: "Would an agent miss this without help?" If not, it's out.

---

## Communication (mandatory)

- Always communicate with the user **in the same language they used**.
- Use the **`caveman`** skill to reduce tokens. Code, commits, security messages, and PRs are written normally.
- If the user is confused or the action is irreversible, drop caveman temporarily and clarify in neutral Spanish.
- Manage your work as a To-Do list (`todowrite` tool): mark `in_progress` for one task at a time, `completed` when done.

## Subagents

- Use subagents in parallel or sequentially as the request demands. Subagents can complete tasks or analyses individually.
- Delegable: `cavecrew-investigator` (locate code, read-only), `cavecrew-builder` (1-2 files, mechanical edits), `cavecrew-reviewer` (review diffs).
- For open-ended multi-step exploration, prefer `explore` or `general`.

---

## What this project is

Flutter package (`flutter_umami_analytics` v1.0.0) — Dart/Flutter client for Umami Analytics. Tracks pageviews, events, and sessions; offline queue (disabled/inMemory/persisted SQLite), NavigatorObserver, persistent device ID (secure storage), optional REST API client. SDK `^3.4.0`, Flutter `>=3.22.0`.

Platforms: android, ios, macos, windows, linux, web. Web-only code (`package:web`) and native-only code (`dart:io`, `sqflite`) sit behind conditional exports (`infrastructure/platform/host_environment.dart`, `infrastructure/queue/persisted_queue_builder.dart`); never import them directly. Run `flutter test --platform chrome` too (`test/web/` is browser-only).

## Architecture — Hexagonal (ports & adapters)

Strict layout under `lib/src/`:

```
domain/         # Pure Dart. No Flutter, http, sqflite, or flutter_secure_storage.
  models/       # UmamiPayload, QueuedEvent, FlutterUmamiConfig, UmamiQueueConfig, DeviceInfoData
  ports/        # Abstract interfaces: UmamiCollector, HttpClientPort, UmamiQueue,
                #   DeviceInfoPort, DeviceIdPort, UmamiApiPort
  logger/       # UmamiLogger (logging policy)
  utils/        # instance_suffix, json_helpers, safe_async
application/    # FlutterUmamiAnalytics (public facade)
infrastructure/ # Adapters: TrackingCollector, DefaultHttpClient, UmamiApiClient,
                #   InMemoryQueue / PersistedQueue / NoopQueue, DeviceIdService,
                #   DeviceInfoService, UserAgentService, UmamiNavigatorObserver
factory.dart    # createUmamiAnalytics() — assembles adapters
```

**Invariant: dependencies point inward.** `domain` imports nothing from `infrastructure` or Flutter. `infrastructure` implements `ports` from `domain`. If a file under `domain/` imports `package:flutter/*`, `package:http/*`, `package:sqflite/*`, or `package:flutter_secure_storage/*`, it is an architecture bug.

Public API = barrel file `lib/flutter_umami_analytics.dart` only. Do not expose new internal files without exporting them there.

`sealed class` pattern for `UmamiQueueConfig` (disabled/inMemory/persisted) consumed via exhaustive `switch` in `queue_factory.dart`. Adding a variant requires updating the factory and tests or `dart analyze` breaks.

Multi-instance: `instanceName` namespaces the SQLite queue (`umami_queue_{name}.db`) and secure storage keys (`umami_device_id_{name}`, `umami_first_launch_{name}`).

### Key patterns

- **`safeAsync` / `safeBool`** (`domain/utils/safe_async.dart`): standard wrapper for async that must not propagate errors. Used extensively in `TrackingCollector`.
- **Dispose cascade**: facade → collector (`flush` → `queue.close` → `httpClient.dispose`) → `apiClient.dispose`. `try/finally` ensures cleanup even if flush fails.
- **Graceful degradation**: API login failure → returns `null`, no crash. Send failure → enqueue. Flush failure → log and continue.
- **Consume-once `firstReferrer`**: applied only to the first pageview, then cleared.
- **Lazy `sessionId`**: generated on first `identify()`, reused for subsequent calls.
- **Thin facade**: `FlutterUmamiAnalytics` only checks `config.enabled` and delegates; all real logic lives in `TrackingCollector`.

## Commands (verify before PR)

| Task                  | Command                                                                  |
| --------------------- | ------------------------------------------------------------------------ |
| Deps (root + example) | `flutter pub get`                                                        |
| Analyze (strict)      | `dart analyze`                                                           |
| All unit tests        | `flutter test`                                                           |
| Single file           | `flutter test test/queue_test.dart`                                      |
| Single test by name   | `flutter test --plain-name "InMemoryQueueConfig default maxSize is 500"` |
| Example app           | `cd example && flutter run`                                              |
| Publish (dry-run)     | `flutter pub publish --dry-run`                                          |

**Mandatory order before commit**: `dart analyze` → `flutter test`. Both must pass clean. `strict-casts` and `strict-inference` are active; code that violates them breaks analyze.

### `tool/umami_test_flow.dart` — live integration

E2E simulator against a real Umami instance (not a `flutter test` test). Requires:

```
UMAMI_WEBSITE_ID=...  UMAMI_ENDPOINT=https://...  UMAMI_HOSTNAME=...  \
[UMAMI_API_USER=...  UMAMI_API_PASS=...]  dart run tool/umami_test_flow.dart
```

Real network, 12 phases, 30+ TCs. Phases 10-11 (API + E2E) run only when `UMAMI_API_USER`/`UMAMI_API_PASS` are set. Has `ignore_for_file: avoid_print, unnecessary_string_interpolations` at the top — **do not replicate that ignore in lib/ or test/ code**.

## Conventions (differ from defaults)

`analysis_options.yaml` enforces non-standard rules:

- **`always_use_package_imports: true`** → imports ALWAYS use `package:flutter_umami_analytics/...`. **Relative imports forbidden** (`./`, `../`). Applies even inside `lib/src/`.
- `prefer_single_quotes: true` → single quotes.
- `prefer_const_constructors` + `prefer_const_declarations` → add `const` wherever possible.
- `always_declare_return_types: true` → every method/function must have an explicit return type.
- `avoid_print: true` → use `UmamiLogger`, never `print` in lib/. `tool/` is the only exception (with file-level ignore).
- `require_trailing_commas: false` → do **not** add trailing commas by default.
- `missing_return: error`, `dead_code: warning`.

### Code style (observed patterns)

- Manual fakes/mocks (no `mockito`): `TestDeviceId`, `TestDeviceInfo`, `SimulatedHttpClient` in `tool/`. Tests in `test/` use lightweight inline fakes.
- Snake_case for files; CamelCase for classes. Public constants prefixed `k` (e.g. `kDefaultQueueMaxSize`), private constants prefixed `_k` (e.g. `_kFirstOpenEvent` in `factory.dart`).
- Prefer **enumerations** over magic strings (see `TestPhase` in `tool/`, `UmamiLogLevel` in logger).
- Early returns, short functions, single responsibility.
- `UmamiConfigOverrides` typedef in `collector_port.dart` — per-call config override map.

### Documentation — dartdoc (mandatory on new/changed code)

Every new or modified public symbol MUST carry `///` dartdoc comments. Inline `//` comments stay optional (only for non-obvious context); dartdoc is the contract for consumers and feeds `doc/api/` (`dart doc` output).

**Minimum required when adding/changing code:**

- **Library** at top of each `lib/src/**/*.dart` file: one `///` block summarizing purpose and layer (`domain`/`application`/`infrastructure`).
- **Public classes** (`FlutterUmamiAnalytics`, `UmamiPayload`, `UmamiCollector`, `UmamiQueue`, ports, adapters, observer, logger): class-level `///` with intent + responsibilities + ownership layer.
- **Public constructors**: one `///` line describing required vs optional params and the resulting state.
- **Public methods/getters** (every `track`, `identify`, `flush`, `dispose`, `pageView`, `enqueue`, `send`, `login`, `init`…): `///` with: what it does, when to call it (ordering vs lifecycle), async/sync, side-effects (enqueue, network, storage, session), null/error semantics.
- **Public fields/named params** exposed via the barrel or via `UmamiConfigOverrides`: one `///` line stating default, units, and constraints.
- **Sealed variants** (`UmamiQueueConfig` subclasses): `///` explaining when to pick each variant + storage/limit trade-offs.

**Style:**

- First sentence = imperative summary; Dart analyzer uses it for hover/tooltip.
- Reference other symbols with `[brackets]` so `dart doc` links them.
- Do NOT dartdoc trivial `_` private helpers, generated code, or `tool/` scripts.
- No dartdoc on test files (`test/`).

Verify with `dart doc` (clean run, no broken links) before pushing if you touched public API.

## Tests

Three files: `flutter_umami_analytics_test.dart` (orchestration/config), `payload_test.dart` (serialization), `queue_test.dart` (queue). All use `flutter_test` and import via the public barrel.

Helpers at the top of the main test file — **reuse them** when adding tests:

- `makeConfig({...})` — factory with sensible defaults (`websiteId: 'test-id'`, `endpoint: 'https://example.com'`, etc.)
- `makeLogger()` → returns `({UmamiLogger logger, List<String> logs})` record; captures log messages for assertion.

No CI pipeline (`.github/` does not exist). `dart analyze` + `flutter test` run locally.

## Files & directories

- `doc/` → `dart doc` output, **gitignored**. Do not commit.
- `doc/` → human docs in Spanish (`doc/es/1-*.md` … `10-*.md`) + `doc/architecture.md` (mermaid diagrams). Committed. `doc/api/` is `dart doc` output, gitignored.
- `example/` → separate Flutter app with `path: ../` dependency. Has its own `pubspec.yaml` and `pubspec.lock`.
- `pubspec.lock` and `*.lock` are gitignored (public package). Do not commit root locks.

---

## Standard task: code analysis

When the user requests code analysis, apply this checklist and report actionable improvements. Run reviews by layer (architecture → quality → performance), preferably with parallel subagents per layer.

### Architecture

- Maintain hexagonal architecture: separation `domain` ↔ `application` ↔ `infrastructure`.
- Report violations (e.g. domain importing frameworks or infrastructure; business logic in adapters).
- **No relative imports** (`./`, `../`) — always `package:flutter_umami_analytics/...`. The `always_use_package_imports` rule enforces this.

### Code quality

- **Names**: clear, descriptive, consistent with the rest of the project.
- **DRY**: detect duplication; extract to common function/module (e.g. `domain/utils/`).
- **Early return** over deep nesting.
- **Small functions** with single responsibility: flag functions/methods doing too much and suggest splitting.
- **Error handling**: explicit — no empty `catch`, no silent failures (see pattern in `factory.dart:_initApiClient`).
- **Style consistency** with `analysis_options.yaml` conventions.
- **Cyclomatic complexity**: flag high-complexity blocks and suggest division.
- **Comments**: self-explanatory code; inline comments only where they add non-obvious context. Dartdoc on public symbols is mandatory — see Documentation section.
- **Enumerations** preferred over magic strings.

### Performance

- Correct memory usage; avoid unnecessary allocations.
- No redundant computations inside loops (hoist invariants out).
- Detect leaks: streams/listeners/`Timer`/controllers not released in `dispose()`. Every adapter holding resources must implement `dispose()` (see `TrackingCollector.dispose`, `UmamiApiClient.dispose`).
