# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Layout

The Flutter app lives in `finance_app/` — run all Flutter/Dart commands from that directory, not the repo root. It is a cash-flow control app ("Controle de Caixa") for stores, in Brazilian Portuguese (the only supported locale is `pt_BR`; UI strings, code identifiers, and comments are in Portuguese).

## Commands

```powershell
cd finance_app
flutter pub get                # install dependencies
flutter run                    # run the app (android/ios/web/windows/linux/macos targets exist)
flutter analyze                # lint (flutter_lints; deprecated_member_use is ignored)
flutter test                   # run all tests
flutter test test/widget_test.dart   # run a single test file

# Regenerate json_serializable models (*.g.dart) after editing files in lib/models/
dart run build_runner build --delete-conflicting-outputs

# Regenerate app icons after changing assets/images/logo.png
dart run flutter_launcher_icons
```

## Architecture

**State management** is Provider-based, wired in `lib/main.dart`:
- `AuthProvider` — login state; persists user + `idLojas` (store IDs) in SharedPreferences when "remember me" or token login is used.
- `ThemeProvider` — light/dark theme (themes defined in `lib/utils/app_theme.dart`).
- `GlobalState` (`lib/services/global_state.dart`) — a plain singleton (not a Provider) holding the logged-in `idLojas`; `ApiService` reads `GlobalState().firstIdLoja` to scope API calls. AuthProvider must keep it in sync on login/logout.

**API layer**: `lib/services/api_service.dart` is the single HTTP client, pointed at `http://api.premiosistemas.com.br`. There is no dependency injection — pages and dialogs instantiate `ApiService()` directly. All endpoints return an envelope `{ success, data, msg }`; `_handleRequest` centralizes decoding and error logging (including detecting HTML-instead-of-JSON responses from unimplemented endpoints).

**Remote error/event logging**: `LoggerService` (singleton) posts errors to `/v1/erro` and events to `/v1/evento` on the **api-master** (`apiBaseUrl`), not on the finance-api — see `lib/services/api_config.dart`. The prevailing pattern is: catch, `await _logger.logError(...)`, then rethrow or return false — follow it in new code. Logging failures are always swallowed so they never break the app.

Every log line carries `id_software = 10` (`idSoftwareFinance`) and `versao = versaoLog`, both in `api_config.dart`. Neither is cosmetic: `id_software` is what attributes the line to the Finance in the support panel, and the api-master accepts the payload without it, writing a NULL in silence. `versao` is the only *persisted* field that distinguishes an app error from a finance-api error — both send `id_software = 10`, and `origem` never reaches the database (`Erro.to_supabase()` in the api-master does not map it). `test/log_contrato_test.dart` locks both.

The finance-api sends to the same place, via `Util/log_api.py` there. Deserialization (`fromJson`) deliberately does **not** log remotely: it runs once per item, so a malformed list would emit one line per record — `ApiService` already logs the whole request once, with endpoint and body.

**Routing and token login** (`lib/main.dart`): named routes exist for `/login`, `/dashboard`, `/caixas`, `/receitas`, `/despesas`. Any *other* non-root path is treated as a login token: `onGenerateRoute` hands it to `TokenLoginWrapper`, which decodes it via `TokenService` (URL-safe Base64 of a CNPJ, padding stripped) and calls `AuthProvider.loginByToken`. Keep this in mind when adding routes — a new named route must be added to the known-routes check in `onGenerateRoute` or it will be interpreted as a token.

**Models** (`lib/models/`): json_serializable classes with generated `.g.dart` companions — never edit `.g.dart` by hand; rerun build_runner instead.

**Responsiveness**: the app uses `responsive_framework` with breakpoints MOBILE (≤450), TABLET (≤800), DESKTOP (≤1920), 4K, plus helpers in `lib/utils/responsive_utils.dart`. Loading states use shimmer placeholders from `lib/widgets/shimmer_widgets.dart`; charts use `fl_chart` under `lib/widgets/charts/`.
