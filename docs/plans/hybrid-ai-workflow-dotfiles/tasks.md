# Zadania: Hybrid AI Workflow w `mmalyska/dotfiles`

Kontekst, audit, decyzje i ryzyka: [plan.md](./plan.md). Każde zadanie = jeden commit (`feat|refactor|test|docs(ai): …`), wykonanie SOLO, w worktree
`.worktrees/<type>/<slug>` (nie w primary checkout). Oznaczaj `- [x]` po zaliczeniu kryterium.

**Konwencje testów** (tworzone w T01): `tests/ai/run.sh` uruchamia `tests/ai/test_*.sh`; render szablonu:
`chezmoi --source "$PWD" --config tests/ai/fixtures/<f>.toml execute-template < <plik.tmpl>`; stuby CLI w `tests/ai/stubs/` logują
argumenty do `$AI_TEST_LOG`; sterowanie awarią: `STUB_FAIL="<subcmd>"`. Chezmoi 2.73.1, bash.
Testy `chezmoi init` (T03) pracują **wyłącznie na kopii drzewa repo** w `$T=$(mktemp -d)` (`rsync -a --exclude .git ./ "$T/src/"`), z `--source "$T/src"`
`--config "$T/chezmoi.toml"` `--destination "$T/home"`, nigdy z `--apply`, zawsze z `</dev/null` i `timeout 30`. Flagi odpowiedzi kluczowane **tekstem promptu**
(stałe `PROMPT_PROFILE="AI profile"`, `PROMPT_TEAMS="Enable Claude agent teams"` w `tests/ai/lib.sh`); tryb nieinteraktywny = `--promptDefaults` (nie `--no-tty`).

**Mapowanie PR (rev. 2):** PR-1 = T00, T01, T02, T03, T04, T04a, T11a · PR-2 = T05–T07 · PR-3 = T08–T09 · PR-4 = T10 · PR-5 = T11b, T12, T13 · zewn. = T14.

---

## Zadania

### T00: Baseline i golden obecnych renderów (PR-1)

**Pliki:** Create `tests/ai/fixtures/legacy-linux.toml`, `legacy-darwin.toml`, `legacy-windows.toml`, `legacy-devcontainer.toml` (każdy: `[data]` z
`email`, `user`, `is_work=false`, `is_wsl`, `is_arch`, `is_devcontainer` — **bez** kluczy `ai_*`); Create `tests/ai/golden/legacy.settings.json` (render
`home/dot_claude/settings.json.tmpl` z `legacy-linux.toml` na **niezmienionym** `96a0802`); Create `docs/workflow/evidence/T00-baseline.md`.
**Zmiana:** zamrozić stan wyjściowy. W evidence: wersje `claude`, `codex`, `opencode`, `chezmoi`; `claude plugin list --json`; `codex plugin list`;
`git rev-parse HEAD`; wynik renderu bez błędu dla 4 fixtures.
**Zależności:** brak.
**Testy:** `for f in tests/ai/fixtures/legacy-*.toml; do chezmoi --source "$PWD" --config "$f" execute-template < home/dot_claude/settings.json.tmpl | python3 -m json.tool >/dev/null && echo OK $f; done` → 4× `OK`.
Skan sekretów: `grep -nEi 'ghp_|sk-[a-z0-9]|api[_-]?key|password' tests/ai/golden/*` → brak trafień.
**Oczekiwany rezultat:** golden jest poprawnym JSON i zawiera `AGENT_TEAMS":"1"`, `superpowers@claude-plugins-official` oraz 12 wpisów `*@mmalyska-claude-plugins`; evidence zawiera wersje CLI.
**Kryterium:** powyższe + `git status --porcelain` poza `tests/ai`, `docs/workflow/evidence` puste.
**Rollback:** `git rm -r tests/ai docs/workflow/evidence/T00-baseline.md` (wyłącznie dodane pliki).

### T01: Harness testów offline ze stubami CLI (PR-1)

**Pliki:** Create `tests/ai/run.sh`, `tests/ai/lib.sh` (asercje `assert_eq`, `assert_contains`, `assert_not_contains`, `assert_calls <log> <regex>`, stałe promptów,
`new_tmp` z `trap` sprzątającym wyłącznie własny katalog), `tests/ai/stubs/claude`, `tests/ai/stubs/codex` (wykonywalne), `tests/ai/test_golden_legacy.sh`.
**Zmiana:** stuby dopisują `"$(basename $0) $*"` do `$AI_TEST_LOG`, domyślnie exit 0; `STUB_FAIL` (lista podkomend po spacji) wymusza exit 1; `claude plugin list --json`
i `codex plugin list` zwracają stan z pliku `$STUB_STATE` (pusty = nic nie zainstalowane). `run.sh` ustawia `HOME=$(mktemp -d)` dla testów, zwraca ≠0 przy pierwszym FAIL
i drukuje `NOT RUN` dla testów natywnych. `test_golden_legacy.sh`: render z `legacy-linux.toml` == `golden/legacy.settings.json` (po `python3 -m json.tool --sort-keys`).
**Zależności:** T00.
**Testy:** `bash tests/ai/run.sh`; negatyw: dopisz spację do kopii golden → `FAIL`, exit ≠ 0 (cofnąć); `env -i PATH=/usr/bin:/bin:$PWD/tests/ai/stubs bash tests/ai/run.sh` (bez prawdziwych CLI).
**Oczekiwany rezultat:** `PASS test_golden_legacy`, exit 0; negatyw exit ≠ 0; brak sieci i brak prawdziwego `claude`/`codex` w PATH nie przeszkadza.
**Kryterium:** harness działa offline, nie czyta ani nie zapisuje w prawdziwym `$HOME` (asercja: `find "$REAL_HOME" -newer <znacznik>` bez nowych plików poza oczekiwanymi cache'ami — patrz T04a).
**Rollback:** `git revert <commit>`; brak wpływu na `$HOME`.

### T02: Dane `ai-workflow.yaml` + acceptance record (PR-1)

**Pliki:** Create `home/.chezmoidata/ai-workflow.yaml`; Create `docs/workflow/acceptance.md`; Create `tests/ai/test_data.sh`.
**Zmiana:** klucz główny `ai_workflow:` z:
`marketplace.own: {name: mmalyska-claude-plugins, repo: mmalyska/claude-plugins, accepted_sha: 25d785abee26ca7a3c87e8311f46e8a90f225301, accepted_tag: "", pin_mode: verify}`;
`marketplace.official: {name: claude-plugins-official, repo: anthropics/claude-plugins-official}`;
`plugins.workflow: [git-workflows, development-lifecycle]`;
`plugins.own: [personal-essentials, git-workflows, development-lifecycle, dotnet, frontend, backend, devops, security, agent-toolkit, renovate, devcontainer, android]`;
`plugins.claude_extras: [superpowers, code-simplifier, context7, claude-md-management]`;
`profiles: {minimal: {own_set: workflow, extras: false}, core: {own_set: own, extras: false}, claude-extended: {own_set: own, extras: true}}` (brak `bare`).
`acceptance.md`: tabela (SHA `25d785a…`, data 2026-10-30, status „qualified preview", planowany tag `ai-workflow-v0.1.0-preview.1` — **jeszcze nie utworzony**, wersje CLI z T00,
pin: Codex `--ref` OK / Claude SHA nieobsługiwany — dowody z plan.md §1.3, link do specyfikacji, procedura upgrade → `upgrade-runbook.md`).
**Zależności:** T00.
**Testy (`test_data.sh`):**

1. dowód ładowania na prawdziwym pliku: `chezmoi --source "$PWD" --config tests/ai/fixtures/legacy-linux.toml execute-template '{{ .ai_workflow.marketplace.own.accepted_sha }}'` → `25d785abee26ca7a3c87e8311f46e8a90f225301`; to samo dla `legacy-darwin|windows|devcontainer`;
2. `chezmoi … data --format json | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "ai_workflow" in d'` → exit 0;
3. `len .ai_workflow.plugins.own` = 12, `len …workflow` = 2, `len …claude_extras` = 4; `workflow ⊂ own`; brak duplikatów; `accepted_sha` ma 40 znaków hex; `accepted_tag` pusty lub dokładnie `ai-workflow-v0.1.0-preview.1`;
4. każdy profil z `profiles` wskazuje istniejący `own_set`; profilu `bare` nie ma;
5. negatyw: kopia drzewa z uszkodzonym YAML (`x: [`) → render kończy się błędem parsowania (exit ≠ 0), nie pustą wartością;
6. lista `plugins.own` == lista z `marketplace.json` na `25d785a` (`gh api …?ref=25d785a`; `NOT RUN` bez `gh`/sieci — w CI `NOT RUN`, lokalnie obowiązkowe przed PR).
**Oczekiwany rezultat:** testy 1–5 PASS offline; 6 PASS lokalnie albo jawnie `NOT RUN`.
**Kryterium:** dane renderują się na wszystkich fixtures; żaden istniejący plik nie konsumuje danych (zero zmiany zachowania).
**Rollback:** `git revert`; plik danych nieużywany przez nic poza testami.

### T03: Wybór profilu: `.chezmoi.toml.tmpl` (logika D-G) + `ai-profile.tmpl` (PR-1)

**Pliki:** Modify `home/.chezmoi.toml.tmpl` (logika D-G przed `[data]`; w `[data]` pięć kluczy); Create `home/.chezmoitemplates/ai-profile.tmpl`;
Create `tests/ai/fixtures/{minimal,core,extended}-linux.toml` (z jawnymi `ai_profile`/`ai_agent_teams`); Create `tests/ai/test_profile.sh`, `tests/ai/test_init.sh`.
**Zmiana:**

- `.chezmoi.toml.tmpl`: `$existing := stat .chezmoi.configFile`; `$legacyHost := and $existing (not (hasKey . "ai_profile"))`. Gdy `$legacyHost`: `ai_profile="claude-extended"`, `ai_agent_teams=true`, `ai_claude=true`, `ai_codex=true`, `ai_opencode=false` — **bez pytań**.
  W przeciwnym razie: `promptChoiceOnce . "ai_profile" "AI profile" (list "minimal" "core" "claude-extended") "core"`, `promptBoolOnce … "ai_agent_teams" "Enable Claude agent teams" false`,
  `promptBoolOnce` dla `ai_claude` (`true`), `ai_codex` (`true`), `ai_opencode` (`false`). Wszystkie pięć kluczy emitowane jawnie w `[data]` (płaskie, jak `is_work`). Istniejące klucze (`email`, `user`, `is_work`, …) bez zmian.
- `ai-profile.tmpl`: wypisuje `PROFILE=<p>` i `FALLBACK=<true|false>`. `hasKey . "ai_profile"` → wartość, `FALLBACK=false`; brak klucza → `claude-extended`, `FALLBACK=true` (przejściowe zabezpieczenie `apply` na hoście, który nie wykonał jeszcze `init`; **nie** służy do odróżniania nowych hostów, bo `init` zawsze zapisuje klucze).
  Wartość spoza `minimal|core|claude-extended` (w tym `bare`) → `fail "unknown ai_profile …"`. Dodatkowo `ai_agent_teams`: klucz obecny → wartość; brak → `true` przy `FALLBACK=true`.
**Zależności:** T02.
**Testy (`test_profile.sh`, render):** fixture legacy → `PROFILE=claude-extended FALLBACK=true`; `core-linux` → `PROFILE=core FALLBACK=false`; `ai_profile="bare"` i `"bogus"` → exit ≠ 0 z `unknown ai_profile`.
**Testy (`test_init.sh`, na kopii drzewa w `$T`, patrz konwencje):**

1. *nowy host:* brak pliku konfiguracji, `init --promptDefaults` → plik zawiera `ai_profile = "core"`, `ai_agent_teams = false`, `ai_claude = true`, `ai_codex = true`, `ai_opencode = false`;
2. *nowy host z wyborem:* `init --promptChoice "AI profile=minimal" --promptBool "Enable Claude agent teams=false"` → `minimal`/`false`;
3. *istniejący host bez klucza, `apply` bez `init`:* konfiguracja ze starego szablonu (bez `ai_*`) + render settings → identyczny z golden legacy (`FALLBACK=true`);
4. *istniejący host, `init`:* `init --promptDefaults` **oraz** `init` bez flag z `</dev/null` (musi zakończyć się exit 0 bez pytania) → jawnie `claude-extended`, `ai_agent_teams = true`; **nie** `core`; kolejny `init` daje identyczny plik (`diff` pusty);
5. *migracja po pierwszym świadomym wyborze:* po kroku 4 `init --prompt --promptChoice "AI profile=core" --promptBool "Enable Claude agent teams=false"` → `core`/`false`; kolejny `init --promptDefaults` zachowuje `core` (Once);
   render settings przed/po: znikają wyłącznie wpisy `*@claude-plugins-official` z `enabledPlugins` i `AGENT_TEAMS`; reszta bez zmian; log stubów CLI pusty (żaden `uninstall|remove|disable`);
6. *flagi kluczowane tekstem promptu:* `init --promptDefaults --promptChoice "ai_profile=minimal"` (zła forma, klucz zamiast tekstu promptu) **nie** zmienia wyniku (zostaje domyślne `core`); bez `--promptDefaults` i bez TTY kończy się błędem — test dokumentuje kontrakt; stałe `PROMPT_*` w `lib.sh` == teksty w `.chezmoi.toml.tmpl` (`grep`);
7. *istniejące klucze:* host z `email/user/is_work` zachowuje je bez zmian po `init`; plik konfiguracji parsuje się jako TOML (`python3 -c 'import tomllib…'`);
8. `init` nigdy nie zapisuje poza `$T` (snapshot `find` w prawdziwym `$HOME` przed/po — bez nowych plików).
**Oczekiwany rezultat:** wszystkie 8 przypadków + testy renderu PASS; golden z T01 nadal zielony.
**Kryterium:** nowa inicjalizacja → jawny `core`/`false`; istniejący host → ten sam efekt co przed zmianą w `apply` **i** po `init`; brak pytań na istniejących hostach.
**Rollback:** `git revert`; istniejące pliki konfiguracji nie są zmieniane przez `apply` (tylko przez `init`), a zapisane klucze `ai_*` są po revert nieużywanymi danymi.

### T04: `settings.json.tmpl` sterowany profilem (PR-1)

**Pliki:** Modify `home/dot_claude/settings.json.tmpl` (l.3 `env`, l.159 `enabledPlugins`, l.181 `extraKnownMarketplaces`); Create `tests/ai/golden/{minimal,core,extended}.settings.json`; Create `tests/ai/test_settings.sh`.
**Zmiana:** (1) `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` emitowany wyłącznie gdy `ai_agent_teams` (lub `FALLBACK` bez klucza) — reszta `env` bez zmian; (2) `enabledPlugins` generowane pętlą z zestawu profilu
(`plugins.workflow` dla `minimal`, `plugins.own` dla `core`/`claude-extended`) jako `<n>@mmalyska-claude-plugins`, plus `claude_extras` jako `<n>@claude-plugins-official` tylko gdy profil ma `extras`;
(3) `extraKnownMarketplaces` zawsze zawiera `mmalyska-claude-plugins` (każdy profil go używa), oficjalny tylko gdy `extras`; źródło `{"source":"github","repo":<z danych>}` — **bez** `ref` (R4);
(4) pozostałe sekcje (hooki, `model`, statusline, `preferences`) bez zmian; przecinki poprawne dla każdej kombinacji.
**Zależności:** T03.
**Testy (`test_settings.sh`):** legacy×4 fixtures → render == `golden/legacy.settings.json` (po `--sort-keys`); `minimal`: dokładnie 2 wpisy (`git-workflows`, `development-lifecycle`) w `enabledPlugins`, brak `superpowers`,
brak `claude-plugins-official`, brak `AGENT_TEAMS`; `core`: 12 wpisów `*@mmalyska-claude-plugins`, brak oficjalnych, brak `AGENT_TEAMS`; `extended`: 16 wpisów, jest `superpowers@claude-plugins-official`, brak `AGENT_TEAMS`;
`extended` + `ai_agent_teams=true` → `AGENT_TEAMS":"1"`; każdy render parsuje się `python3 -m json.tool`; w żadnym renderze nie ma `STANDARD|SOLO|Spec|profile|topology|lifecycle` (D-E);
skan sekretów jak w T00; `repo` i nazwa marketplace w `extraKnownMarketplaces` == dane (R4); wspólne sekcje (`hooks`, `statusLine`, `model`) identyczne między profilami (`diff` po usunięciu `enabledPlugins`/`extraKnownMarketplaces`/`env`).
**Oczekiwany rezultat:** wszystkie PASS; **render legacy bajt w bajt (po sortowaniu kluczy) identyczny z golden z T00**.
**Kryterium:** testy PR-1 zielone; efekt `apply` na hoście legacy nie zmienia `~/.claude/settings.json` (T13 sprawdzi `chezmoi diff` w kontenerze).
**Rollback:** `git revert <commit>` przywraca tekstowy szablon; jedyny zarządzany plik `~/.claude/settings.json` ma dla legacy identyczną zawartość przed i po.

### T04a: CI Linux dla `tests/ai` (PR-1)

**Pliki:** Create `.github/workflows/ai-tests.yml`; Create/Modify `renovate.json5` (tylko jeśli brak pokrycia `.github/workflows`; sprawdzić najpierw, czy repo je ma — dziś go nie ma); Modify `tests/ai/run.sh` (tryb CI: brak `NOT RUN` ukrywanego jako sukces); Create `tests/ai/test_hermetic.sh`, `tests/ai/test_workflow_pins.sh`.
**Zmiana:** workflow `on: pull_request` (ścieżki `home/**`, `tests/ai/**`, `.github/workflows/ai-tests.yml`, `docs/workflow/**`) i `push` na `main`; `permissions: contents: read`; job `linux` na `ubuntu-latest`:
`actions/checkout` i każda inna akcja przypięta do pełnego 40-znakowego commit SHA z komentarzem wersji obok (`uses: owner/action@<40-hex> # v4`; O5), bez `@main`/`@master`/samego `@v4`, instalacja chezmoi **`v2.73.1`** z oficjalnego wydania (wersja przypięta; sposób pobrania zweryfikować przy wdrożeniu), `shellcheck`, `bash tests/ai/run.sh`, krok końcowy `git status --porcelain` musi być pusty.
Zakres walidacji: dane i szablony (T02), rendery `minimal`/`core`/`claude-extended` (T04), golden hosta legacy (T00/T04), default nowego hosta i `init` (T03), brak wymaganych CLI (`env -i PATH` bez `claude`/`codex` — patrz T06/T08 gdy dojdą; w PR-1: harness i `test_hermetic.sh`),
idempotencja logiki na stubach (w PR-1: ponowne `init` i ponowny render dają identyczny wynik; instalatory dojdą w PR-2/3), skan sekretów, brak zmian poza repo (`test_hermetic.sh`: `HOME=$(mktemp -d)`, snapshot `find` katalogu runnera przed/po poza `$RUNNER_TEMP`, `git status --porcelain` puste).
Windows i macOS: **poza PR-1** (dochodzą z instalatorami, T10).
**Zależności:** T01–T04.
**Testy:** lokalnie `bash tests/ai/run.sh` zielony; `tests/ai/test_workflow_pins.sh`: każda linia `uses:` w `.github/workflows/*.yml` pasuje do `@[0-9a-f]{40}\s+#\s*v\S+` i żadna nie zawiera `@main|@master|@v[0-9]+\s*$`; Renovate: konfiguracja repo (`renovate.json5` rozszerzająca `mmalyska/renovate-config`, preset `helpers:pinGitHubActionDigests` lub równoważny z presetów użytkownika — zweryfikować przez agenta `renovate:renovate-auditor` przy wdrożeniu) obejmuje `.github/workflows`; walidacja składni workflow `python3 -c 'import yaml…'` (jeśli dostępny `yaml`, inaczej `actionlint` gdy zainstalowany, inaczej `NOT RUN` z adnotacją w PR); w PR: zielony run na Linuksie; negatyw jednorazowo na gałęzi roboczej: psuje golden → run czerwony (zapis w evidence `docs/workflow/evidence/T04a-ci.md`).
**Oczekiwany rezultat:** CI czerwone przy zmianie golden/danych/promptów oraz przy `uses:` bez 40-znakowego SHA, zielone na czystym branchu; log pokazuje wersję chezmoi 2.73.1 i brak `claude`/`codex` w PATH.
**Kryterium:** wymagany check dla PR-1 jest zielony; żaden krok nie wymaga sekretów ani zapisu poza katalogiem roboczym runnera.
**Rollback:** `git revert` (usuwa workflow i testy hermetyczności); brak wpływu na hosty.

### T05: Wspólna biblioteka shell `ai-lib.sh` (PR-2)

**Pliki:** Create `home/.chezmoitemplates/ai-lib.sh`; Create `tests/ai/test_lib.sh`.
**Zmiana:** funkcje (bash 3.2-kompatybilne): `ai_log <LEVEL> <msg>` (`INFO|SKIP|WARN|DONE` na stderr, prefiks `[ai-workflow]`); `ai_have <cmd>` (`command -v`);
`ai_soft <opis> -- <cmd…>` (uruchamia, loguje `WARN` przy ≠0, zwiększa `AI_FAILS`, zwraca 0); `ai_summary <harness>` (drukuje `DONE <harness> fails=<n>`, zawsze exit 0);
`ai_marketplace_head <dir>` (`git -C … rev-parse HEAD` lub pusty). Dołączana przez `{{ template "ai-lib.sh" . }}`; nie czyta danych.
**Zależności:** T01.
**Testy (`test_lib.sh`):** `ai_have nonexistent_cmd_xyz`; `ai_soft x -- false`; `ai_summary` przy `AI_FAILS=2`; `bash -n`; `shellcheck` jeśli dostępny.
**Oczekiwany rezultat:** `ai_have` zwraca ≠0; `ai_soft` zwraca 0 i `AI_FAILS=1`; `ai_summary` drukuje `DONE … fails=2` i exit 0; `bash -n` czysty; shellcheck bez błędów lub `NOT RUN`.
**Kryterium:** testy zielone (także w CI); biblioteka nie czyta ani nie zapisuje niczego w `$HOME`.
**Rollback:** `git revert` (plik nieużywany do T06).

### T06: Instalator Claude Code — idempotentny, niezależny, z weryfikacją pinu + spike S1 (PR-2)

**Pliki:** Create `home/.chezmoiscripts/ai/run_onchange_after_100-claude-plugins.sh.tmpl`; Create `tests/ai/test_claude_installer.sh`; Create `docs/workflow/evidence/T06-claude-cli.md` (kroki 1–2).

- [ ] **Krok 1 (weryfikacja CLI, evidence):** `claude plugin list --help`, `claude plugin install --help`, `claude plugin marketplace list --json` — potwierdzić `--json` i format; w izolowanym `CLAUDE_CONFIG_DIR` (poza `/tmp`) zainstalować ten sam plugin dwa razy i zapisać kody wyjścia (czy `install` jest idempotentne). Nie zakładać wyniku.
- [ ] **Krok 2 (spike S1 — pin tagiem, timebox 30 min, tylko evidence, bez zmian w GitHub):** w scratchpadzie utworzyć **lokalny** klon `claude-plugins` na `25d785a` z **lokalnym** tagiem `ai-workflow-v0.1.0-preview.1`
  (bez `git push`), po czym w izolowanych `CLAUDE_CONFIG_DIR`: (a) `claude plugin marketplace add "file://<klon>#ai-workflow-v0.1.0-preview.1"` (lub równoważna forma git-URL) — czy działa i czy `git rev-parse HEAD` w katalogu marketplace == `25d785a…`;
  (b) wpis `extraKnownMarketplaces.<m>.source` z `ref` = tag (`source: git`/`github`) + `marketplace add` z tym samym źródłem — czy `ref` jest respektowany; (c) czy `claude plugin marketplace update` zostaje na tagu czy przesuwa się do HEAD gałęzi;
  (d) kontrola negatywna: SHA jako ref (już zmierzone: odrzucone). Wynik **rozstrzyga**: tag działa w (a)+(b)+(c) ⇒ T14 może przełączyć `pin_mode` na `tag`; w przeciwnym razie `pin_mode: verify` zostaje na stałe, a tag służy tylko Codex i jako etykieta. Zapisać też, czy forma GitHub `owner/repo#tag` różni się od `file://` (nie przesądzać — dodatkowa weryfikacja po utworzeniu prawdziwego tagu, T14).
- [ ] **Krok 3 (implementacja):** skrypt `.sh.tmpl` z odciskiem na górze (`# profile={{…}} claude={{ .ai_claude }} sha={{ accepted_sha }} cli={{ if lookPath "claude" }}present{{ else }}absent{{ end }} plugins={{ lista zestawu profilu }}`). Logika:
  1. `ai_claude=false` → `SKIP`, exit 0;
  2. `! ai_have claude` → `SKIP claude CLI not found`, exit 0;
  3. marketplace własny: `claude plugin marketplace add <repo z danych>` tylko jeśli brak w `marketplace list --json`; **bez** `marketplace update`, chyba że `AI_WORKFLOW_UPGRADE=1`;
  4. drift: `ai_marketplace_head "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/marketplaces/<name>"` ≠ `accepted_sha` → `WARN drift` (nie błąd);
  5. pluginy zestawu profilu (`minimal` = 2, `core`/`claude-extended` = 12) — instalować tylko brakujące, przez `ai_soft`;
  6. profil z `extras`: marketplace oficjalny (jak 3), potem 4 dodatki przez `ai_soft` (zastępuje `|| true`);
  7. `ai_summary claude`.
**Zależności:** T04, T05.
**Testy (`test_claude_installer.sh`, stub CLI):** (a) brak `claude` w PATH; (b) świeży stan `core`; (c) drugie uruchomienie z pełnym `$STUB_STATE`; (d) `claude-extended`; (e) `STUB_FAIL="install"`; (f) `minimal` świeży stan; (g) `AI_WORKFLOW_UPGRADE=1`; (h) head ≠ accepted; (i) odcisk przy CLI present vs absent; (j) `ai_claude=false`.
**Oczekiwany rezultat:** (a) exit 0, log `SKIP`, zero wywołań; (b) 1× `marketplace add`, 12× `install`, **0×** `marketplace update`, **0×** `superpowers`; (c) 0 wywołań mutujących (`add|install|update`); (d) dodatkowo `marketplace add anthropics/claude-plugins-official` i 4 instalacje z `superpowers`;
(e) exit 0, `fails=12`, kolejne kroki wykonane; (f) 1× `marketplace add`, dokładnie 2× `install` (`git-workflows`, `development-lifecycle`), 0 dodatków; (g) dokładnie 1× `marketplace update mmalyska-claude-plugins`; (h) `WARN drift`, exit 0; (i) dwa różne odciski (ponowne uruchomienie po instalacji CLI); (j) zero wywołań.
**Kryterium:** (a–j) zielone w CI; evidence z kroków 1–2 zapisane z rozstrzygnięciem pin_mode; w skrypcie brak `|| true` i gołych wywołań `claude` poza `ai_soft`.
**Rollback:** `git revert` (stary `run_once` nadal obecny do T07). Na hoście niczego nie odinstalowuje, więc nie ma stanu do cofania; spike S1 nie zmienia GitHuba ani `~/.claude`.

### T07: Usunięcie starego `run_once` i migracja bez odinstalowywania (PR-2)

**Pliki:** Delete `home/run_once_install-claude-plugins.sh`; Create `tests/ai/test_migration.sh`.
**Zmiana:** usunięcie starego skryptu; `run_onchange_after_100-…` przejmuje rolę. Chezmoi nie usuwa niczego z `$HOME` z powodu usunięcia skryptu.
**Zależności:** T06 (ten sam PR lub wcześniej).
**Testy:** `grep -rn "install-claude-plugins" home tests` ; `test_migration.sh`: (a) host legacy z pełnym `$STUB_STATE` (16 pluginów) — render settings i uruchomienie instalatora; (b) przejście `claude-extended → core → minimal` (render settings + instalator ze stanem pełnym).
**Oczekiwany rezultat:** brak odwołań; (a) render == golden legacy i **0** wywołań mutujących; (b) w kolejnych renderach znikają tylko wpisy `enabledPlugins`, żadne wywołanie stubów nie zawiera `uninstall|remove|disable`.
**Kryterium:** `bash tests/ai/run.sh` zielony; w diffie PR brak `uninstall`.
**Rollback:** `git revert` przywraca stary skrypt (poprzednia wersja idempotentna poza `marketplace update`); stan hostów nie wymaga cofania.

### T08: Instalator Codex + (opcjonalnie) pakiety CLI (PR-3)

**Pliki:** Create `home/.chezmoiscripts/ai/run_onchange_after_110-codex-plugins.sh.tmpl`; Create `tests/ai/test_codex_installer.sh`; Modify (tylko po kroku 1) `home/.chezmoiscripts/macos/run_onchange_000-packages.sh.tmpl`; Create `docs/workflow/evidence/T08-codex-cli.md`.

- [ ] **Krok 1 (weryfikacja pakietów, evidence):** ustalić prawdziwe identyfikatory CLI Codex i Claude Code dla brew/pacman/AUR/winget/npm przez `brew info`, `pacman -Si`, `paru -Si`, `winget show`, `npm view` tam, gdzie narzędzie jest dostępne; reszta `NOT VERIFIED`. **Nie dodawać** pakietu bez dowodu; przy braku pewności instalacja CLI zostaje poza zakresem (R6).
- [ ] **Krok 2 (instalator pluginów):** odcisk jak w T06. Logika: `ai_codex=false` → SKIP; `! ai_have codex` → SKIP exit 0; `codex plugin marketplace add <repo> --ref <accepted_sha>` (zmierzone: powtórzenie exit 0; przy innym refie → `WARN pin mismatch`, bez automatycznej zamiany);
  dla każdego pluginu zestawu profilu (`minimal` 2, `core`/`claude-extended` 12): `codex plugin add <n>@mmalyska-claude-plugins` przez `ai_soft` (zmierzone: idempotentne); **nigdy** `claude_extras`/Superpowers; `ai_summary codex`.
- [ ] **Krok 3 (pakiety, warunkowo):** tylko zweryfikowane identyfikatory, za `{{ if .ai_codex }}`, w stylu istniejących `brew install`.
**Zależności:** T05, T06.
**Testy (`test_codex_installer.sh`, stub):** (a) brak `codex`; (b) `core` świeży; (c) powtórka ze stanem pełnym; (d) `minimal`; (e) `STUB_FAIL="plugin"`; (f) niezależność — uruchomić oba instalatory przy {brak claude, jest codex} i {jest claude, brak codex}; (g) `ai_codex=false`; (h) skan argumentów.
Natywnie (opt-in `AI_NATIVE_TESTS=1`, `CODEX_HOME=$HOME/.cache/ai-workflow-test.XXXX`): dwa przebiegi skryptu.
**Oczekiwany rezultat:** (a) exit 0, SKIP, zero wywołań; (b) 1× `marketplace add … --ref 25d785abee26ca7a3c87e8311f46e8a90f225301`, 12× `plugin add`, 0 z `superpowers`; (c) 0 wywołań mutujących; (d) 2× `plugin add`; (e) exit 0, `fails=12`;
(f) w obu konfiguracjach skonfigurowany harness jest kompletny, brakujący tylko SKIP; (g) zero wywołań; (h) żaden argument nie zawiera `delegate|team|orchestrat`. Natywnie: `config.toml` ma `ref = "25d785a…"`, `[plugins."git-workflows@mmalyska-claude-plugins"] enabled = true`, a drugi przebieg nie zmienia pliku (`diff` pusty).
**Kryterium:** testy stubowe zielone w CI; przebieg natywny opisany w evidence albo `NOT RUN`; pakiety CLI tylko z dowodem.
**Rollback:** `git revert`; na hostach `codex plugin remove <n>` i `codex plugin marketplace remove mmalyska-claude-plugins` **ręcznie** (runbook), nigdy automatycznie.

### T09: `ai-workflow-doctor` — raport tylko do odczytu (PR-3)

**Pliki:** Create `home/dot_local/bin/executable_ai-workflow-doctor.tmpl` (**`.tmpl`**: czyta `accepted_sha`, profil i flagi z danych; cel `~/.local/bin/ai-workflow-doctor`, tryb 0755 — zweryfikowane, że `.tmp` nie jest rozszerzeniem chezmoi); Create `tests/ai/test_doctor.sh`.
**Zmiana:** skrypt bash drukujący tabelę: profil i flagi, obecność `claude`/`codex`/`opencode` + `--version`, stan marketplace (Claude: HEAD vs `accepted_sha` → `OK|DRIFT|ABSENT`; Codex: `ref` z `config.toml` vs `accepted_sha`),
brakujące/dodatkowe pluginy względem profilu, ostrzeżenie gdy `superpowers` jest włączony a profil go nie przewiduje. Zero zapisów, zero `add|install|update`. Exit 0 zawsze; `--strict` → exit 1 przy `DRIFT|MISSING`.
**Zależności:** T06, T08.
**Testy:** (a) nazwa/tryb: `chezmoi … managed` zawiera `.local/bin/ai-workflow-doctor` i nie zawiera `.tmpl`/`.tmp`; po `apply` do katalogu tymczasowego plik jest wykonywalny, a jego treść nie zawiera `{{`; (b) stuby ze stanem pełnym; (c) HEAD ≠ accepted; (d) brak obu CLI; (e) log stubów.
**Oczekiwany rezultat:** (a) PASS; (b) wszystkie `OK`; (c) `DRIFT`, exit 0 (`--strict` exit 1); (d) `ABSENT`, exit 0; (e) brak podkomend mutujących.
**Kryterium:** testy zielone; doctor używany w T13; w dokumentacji wzmianka, że `~/.local/bin` musi być w `PATH`.
**Rollback:** `git revert` (plik pomocniczy, brak wpływu na `apply`); usunięcie `~/.local/bin/ai-workflow-doctor` ręcznie.

### T10: Windows, macOS CI, devcontainer i `.chezmoiignore` (PR-4)

**Pliki:** Modify `home/.chezmoiignore`; Create `home/.chezmoiscripts/ai/run_onchange_after_100-claude-plugins.ps1.tmpl`, `run_onchange_after_110-codex-plugins.ps1.tmpl`; Modify `.github/workflows/ai-tests.yml` (jobs `macos`, `windows`); Create `tests/ai/test_ignore.sh`.
**Zmiana:** `.chezmoiignore`: na `windows` ignorować `*.sh` w `.chezmoiscripts/ai/`, na `linux`/`darwin` — `*.ps1`; devcontainer **nie** ignoruje `ai/`; skrypty PowerShell odwzorowują T06/T08 (`Get-Command … -ErrorAction SilentlyContinue`, SKIP bez CLI, bez `exit 1`). CI: macOS i Windows uruchamiają odpowiednie podzbiory testów renderu/ignorowania.
**Zależności:** T08.
**Testy (`test_ignore.sh`):** `.chezmoiignore` renderowany dla fixtures `linux`, `darwin`, `windows`, `devcontainer` — lista wzorców porównana z tabelą w teście; `pwsh` parse-check (`[System.Management.Automation.Language.Parser]::ParseFile`) jeśli `pwsh` dostępny.
**Oczekiwany rezultat:** na `windows` żaden `.sh` z `ai/` nie jest zarządzany; na `linux/darwin` żaden `.ps1`; w `devcontainer` oba skrypty `ai/` aktywne; `pwsh` parse-check PASS lub `NOT RUN` (jawnie oznaczone w PR jako nieprzetestowane na Windows).
**Kryterium:** żaden OS nie dostaje cudzego skryptu; Windows bez `bash` nie wywala `apply`; joby CI zielone.
**Rollback:** `git revert`; ignorowanie plików nie dotyka `$HOME`.

### T11: Dokumentacja bieżąca vs historyczna, runbook upgrade/rollback, backup (T11a w PR-1, T11b w PR-5)

**Pliki:** T11a — Create `docs/README.md`, `tests/ai/test_links.sh`; T11b — Create `docs/workflow/upgrade-runbook.md`, `docs/workflow/backup.sh` (tylko kopiuje do `~/.local/state/ai-workflow-backup/<UTC>/`).
**Zmiana:** `docs/README.md`: tabela „bieżące" (`docs/plans/**`, `docs/workflow/**`) vs „historyczne, nie wykonywać jako instrukcji" (`docs/superpowers/**`, 3 pliki z 2026-05-15; ścieżka `~/.local/share/chezmoi/home/dot_claude/` nieaktualna) — **bez edycji** tych plików.
`upgrade-runbook.md`: (0) `chezmoi init --promptDefaults` w kontenerach i `--prompt` do świadomej zmiany profilu (z tekstami promptów); (1) backup (`backup.sh`: `settings.json`, `config.toml`, `claude plugin list --json`, `codex plugin list`); (2) test nowej rewizji w izolowanym HOME;
(3) PR zmieniający `accepted_sha` (i `accepted_tag` po T14) + wpis w `acceptance.md`; (4) `AI_WORKFLOW_UPGRADE=1 chezmoi apply`; (5) Claude: `claude plugin marketplace update mmalyska-claude-plugins` + reinstall zmienionych + nowa sesja; Codex: `marketplace add … --ref <nowy>` (przy „pin mismatch": `marketplace remove` + `add` — zweryfikować w T13);
(6) `ai-workflow-doctor --strict`; (7) **rollback** = poprzedni `accepted_sha` + te same kroki; dezaktywacja pluginu przez zmianę profilu; usuwanie tylko ręcznie.
**Zależności:** T11a — T02; T11b — T09.
**Testy:** `tests/ai/test_links.sh` (każdy względny link w `docs/**/*.md` istnieje); `git diff --stat -- docs/superpowers` ; `grep -c "docs/superpowers" docs/README.md`; `backup.sh` ze stubami + `sha256sum` źródeł przed/po.
**Oczekiwany rezultat:** brak martwych linków; diff `docs/superpowers` pusty; grep ≥ 1; `backup.sh` zapisuje 4 pliki i nie zmienia źródeł.
**Kryterium:** nowa sesja z samym `docs/README.md` odróżnia bieżące od historycznych; runbook wykonalny krok po kroku.
**Rollback:** `git revert` (dokumentacja i skrypt pomocniczy).

### T12: OpenCode jako flaga/spike — tylko dokument (PR-5)

**Pliki:** Create `docs/workflow/opencode-spike.md`; (flaga `ai_opencode` istnieje od T03).
**Zmiana:** checklista spike'u wzorowana na `claude-plugins/docs/workflow/compatibility.md#opencode-manual-path-and-future-spike`: przypiąć wersję (wykryta `opencode v2.2.0`), ładowanie `AGENTS.md`, odkrywanie skills, mapowanie permissions/hooks, subagenci/worktrees, instalacja przez dotfiles, 3 scenariusze (QUICK+SOLO, STANDARD+HANDOFF, REVIEW). Jawnie: brak instalatora; `ai_opencode=true` tylko wypisuje w doctorze „spike not implemented".
**Zależności:** T09.
**Testy:** fixture z `ai_opencode=true` vs `false`: render settings i uruchomienie obu instalatorów na stubach; doctor.
**Oczekiwany rezultat:** identyczny render i identyczne logi wywołań; doctor pokazuje wiersz OpenCode informacyjnie.
**Kryterium:** flaga nie zmienia żadnego pliku konfiguracyjnego ani nie instaluje niczego.
**Rollback:** `git revert`.

### T13: Test świeżego środowiska i ponownego `chezmoi apply` (PR-5)

**Pliki:** Create `tests/ai/e2e-fresh-home.sh` (opt-in `AI_NATIVE_TESTS=1`); Create `docs/workflow/evidence/T13-e2e.md`.
**Zmiana:** skrypt tworzy `HOME=$(mktemp -d "$HOME/.cache/ai-e2e.XXXX")` (poza `/tmp`) z własnymi `CLAUDE_CONFIG_DIR`, `CODEX_HOME`; uruchamia `chezmoi init --apply --source <kopia repo> --promptDefaults --promptChoice "AI profile=<p>" …` dla macierzy:
{profil: minimal, core, claude-extended} × {CLI: oba, tylko claude, tylko codex, żaden (PATH bez nich)}; następnie drugi `chezmoi apply`, `chezmoi diff` i `ai-workflow-doctor --strict`. Dodatkowo scenariusz hosta legacy (konfiguracja bez `ai_*` → `apply` → `init` → `apply`). Sprzątanie tylko własnego katalogu (kontrola prefiksu).
**Zależności:** T04, T06, T08, T09, T10.
**Testy:** macierz z opisu zmiany.
**Oczekiwany rezultat:** każda komórka: pierwszy apply exit 0; drugi apply exit 0, `chezmoi diff` pusty, brak wywołań mutujących CLI (log wrapperów); `minimal` → w `settings.json` 2 pluginy, na liście pluginów 2; `core` → brak `superpowers`; `claude-extended` → jest;
po `claude plugin disable superpowers@claude-plugins-official` w izolowanym HOME apply i doctor nadal exit 0; „tylko codex" → Claude SKIP, Codex skonfigurowany (`ref = "25d785a…"`); „żaden" → oba SKIP, exit 0; legacy → render == golden, po `init` jawne `claude-extended`/`true`, kolejny `apply` bez różnic;
brak `STANDARD|SOLO|profile|topology` i sekretów w renderach; retry: `chezmoi state delete-bucket --bucket=scriptState` → instalatory biegną ponownie i nie wykonują operacji mutujących; Codex przy zmianie `accepted_sha` — zmierzyć i zapisać zachowanie `marketplace add --ref <inny>` dla istniejącego wpisu. Komórki bez CLI/sieci → `NOT RUN`, nie PASS.
**Kryterium:** macierz PASS albo jawnie `NOT RUN` z przyczyną; evidence zapisane; prawdziwe `~/.claude`/`~/.codex` nietknięte (`sha256sum` przed/po).
**Rollback:** `git revert`; test nie modyfikuje hosta (własny HOME).

### T14: Zewnętrzne — tag `ai-workflow-v0.1.0-preview.1` w `claude-plugins` (poza dotfiles; tylko na osobne polecenie)

**Pliki:** brak w tym repo do czasu wykonania. Po wykonaniu: Modify `home/.chezmoidata/ai-workflow.yaml` (`accepted_tag`, ewentualnie `pin_mode`), `docs/workflow/acceptance.md`, `docs/workflow/evidence/T14-tag.md`.
**Zmiana:** tag **`ai-workflow-v0.1.0-preview.1`** wskazujący **dokładnie** `25d785abee26ca7a3c87e8311f46e8a90f225301`. **Nie tworzyć** bez osobnego polecenia użytkownika (zmiana publiczna, w cudzym — względem tego repo — projekcie) i **nie przed** zakończeniem S1 (T06 krok 2).
Po utworzeniu: powtórzyć S1 na prawdziwym tagu (`owner/repo#tag` i `source.ref`). Rozstrzygnięcie: Claude akceptuje tag ⇒ osobny PR przełącza `pin_mode: tag` i `extraKnownMarketplaces.source.ref`; Claude nie akceptuje ⇒ `pin_mode: verify` (acceptance record + doctor + kontrolowany upgrade) pozostaje.
**Zależności:** T06 (S1), decyzja/polecenie użytkownika.
**Testy:** `gh api repos/mmalyska/claude-plugins/git/ref/tags/ai-workflow-v0.1.0-preview.1 --jq .object.sha` (dla tagu adnotowanego dodatkowo dereferencja `git/tags/<sha>` → `.object.sha`); natywnie: `CLAUDE_CONFIG_DIR=… claude plugin marketplace add "mmalyska/claude-plugins#ai-workflow-v0.1.0-preview.1"`, następnie `git rev-parse HEAD` w katalogu marketplace; Codex: `--ref ai-workflow-v0.1.0-preview.1`.
**Oczekiwany rezultat:** tag (po dereferencji) == `25d785abee26ca7a3c87e8311f46e8a90f225301`; wynik Claude zapisany w evidence jako PASS (HEAD == SHA) albo FAIL z komunikatem; Codex zapisuje `ref = "ai-workflow-v0.1.0-preview.1"`.
**Kryterium:** zmierzone zachowanie Claude i Codex z tagiem w evidence; do tego czasu obowiązuje `pin_mode: verify` i `accepted_sha`.
**Rollback:** w dotfiles `git revert` zmiany `pin_mode`/`accepted_tag`; usunięcie tagu to osobna decyzja w tamtym repo.

---

## Macierz pokrycia wymagań

| Wymaganie | Zadania |
| --- | --- |
| profile `minimal` (2 pluginy) / `core` (12) / `claude-extended` (+4 oficjalne), wybór przez dane chezmoi | T02, T03, T04, T06, T08 |
| nowy host → jawny `core`; istniejący → fallback `claude-extended` + dotychczasowy agent teams; migracja | T03, T04, T07, T13 |
| CI Linux (dane, rendery, golden, default nowego hosta, brak CLI, idempotencja, sekrety, brak zmian poza repo) | T01, T04a, T10 (Win/macOS) |
| dowód ładowania `.chezmoidata` i nazwa doctora | T02, T09 |
| idempotentne niezależne instalatory Claude i Codex | T05, T06, T08, T13 |
| zachowanie bez CLI | T06(a), T08, T13 |
| rejestracja/aktualizacja marketplace | T06, T08, T11 |
| użycie `25d785a` i tag `ai-workflow-v0.1.0-preview.1` (S1 → osobne polecenie → T14) | plan.md §1.3, T02, T06 (S1), T08, T09, T11, T14 |
| default `STANDARD + SOLO` bez kopiowania | T04, T13 (asercje braku ciągów) |
| brak automatycznej delegacji / orkiestratora | T04 (agent teams off), T08 (asercja argumentów), T13 |
| OpenCode jako flaga/spike | T03 (flaga), T12 |
| migracja bez odinstalowywania | T07, T11 |
| rollback | każde zadanie, plan.md §6, T11 |
| testy świeże + ponowny apply | T13, T01–T10 (stuby) |
| Superpowers opcjonalny | T02, T04, T06, T13 |
| historia Superpowers nietknięta | T11 (`git diff -- docs/superpowers` puste) |
