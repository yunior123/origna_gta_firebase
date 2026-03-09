# Environment & Testing Reference

## Emulator Ports

| Service | Port | Note |
|---------|------|------|
| Auth | 9099 | |
| Firestore | 8080 | |
| Functions | 5001 | |
| Storage | 9199 | |
| UI | 4000 | |
| SPA (Flutter) | 8888 | Use this, NOT port 5005 |

**Project ID:** `orignagta`
**CRITICAL:** Without `--dart-define=ENVIRONMENT=emulator --dart-define=USE_EMULATORS=true`, app connects to PRODUCTION.
**CRITICAL:** Pre-push hook overwrites emulator build. Rebuild after `git push`.

## Test Accounts (Emulator)

| Account | Email | UID | Roles |
|---------|-------|-----|-------|
| Admin | yr62813@gmail.com | gcM3C09wyisNRkp2gJS0y2RVAReT | admin, seller, buyer |
| Yahoo | yuniorrodriguezo4601@yahoo.com | nb80ZX32Rx7PFtCiMiyWg4wmS8dM | buyer, seller |
| Buyer1 | yuniorrodriguezo460@gmail.com | 1BavwSl3O0ObrDakFF3KtbuPXIx1 | buyer |

## Quick Start Commands

```bash
./start-dev.sh                                    # All-in-one dev environment
cd functions && source venv/bin/activate && pytest # Backend tests (288 tests)
cd origna_gta && flutter run -d chrome             # Flutter web
cd e2e && npm test                                 # E2E tests (161+ tests)
./scripts/deploy_with_validation.sh                # Full deploy
```

## Known Issues

- `KeyError: 'authtype'` — emulator bug, harmless
- Emulator `emailVerified` doesn't persist — bypassed in code
- `Address` class collision — use `hide Address` when importing both model files
- **Flutter web integration tests** — ChromeDriver compatibility issues. May need matching Chrome version
- **Firebase emulators sometimes hang** — kill with: `pkill -9 -f 'firebase' 2>/dev/null; pkill -9 -f 'java' 2>/dev/null`
- **iOS Simulator UUID**: `8D0C7CE6-D8DF-487A-8E65-E7504BE44A93`
- **iOS Pods**: If build fails → `cd origna_gta/ios && rm -rf Pods Podfile.lock && pod install --repo-update`
- **Pre-push hook overwrites emulator build** — always rebuild Flutter after `git push`
