# Hybrid AI Engineering Workflow w `mmalyska/dotfiles` — plan

```yaml
profile: DEEP
topology: SOLO
stage: Plan            # Build jeszcze nie rozpoczęty
owner: Claude Code (jedna sesja, bez subagentów, innych harnessów i orkiestratora)
repo: mmalyska/dotfiles
base_sha: 96a0802        # main w chwili planowania
branch: docs/hybrid-workflow-dotfiles-plan
worktree: .worktrees/docs/hybrid-workflow-dotfiles-plan
spec: mmalyska/claude-plugins@25d785abee26ca7a3c87e8311f46e8a90f225301 docs/workflow/specification.md (§2.2, §8.3, §13 PR 2, §14.2, §16)
spec_status: qualified preview; pozostałe full-conformance release gates nie są wymagane
revision: 2 (decyzje użytkownika z 2026-10-30: minimal=2 pluginy, tag ai-workflow-v0.1.0-preview.1 po S1, CI w PR-1, rozróżnienie hostów)
status: zatwierdzony (rev. 2 + O5); wysyłany jako PR-0 (docs only)
next_action: po merge PR-0 — PR-1 (T00, T01, T02, T03, T04, T04a, T11a); wymaga osobnego polecenia
```

> **Dla wykonawcy:** wykonanie SOLO. `superpowers:executing-plans` jest dozwolony, ale **nie wymagany** — plan nie zależy od
> Superpowers. Nie uruchamiaj subagentów, innych harnessów ani orkiestratora bez jawnej zgody użytkownika.
> Zadania i ich kryteria: `tasks.md` (ten sam katalog). Kroki używają checkboxów `- [ ]`.

**Cel:** `dotfiles` instaluje i konfiguruje harnessy (Claude Code, Codex; OpenCode jako flaga), wybiera profil środowiska
z danych chezmoi i rejestruje marketplace `mmalyska/claude-plugins` — bez kopiowania definicji workflow, bez wymuszania
Superpowers i bez delegacji.

**Architektura:** (1) dane statyczne `home/.chezmoidata/ai-workflow.yaml` + wybór użytkownika w `.chezmoi.toml.tmpl`;
(2) szablony renderujące `settings.json` z profilu; (3) niezależne, idempotentne skrypty `run_onchange_` per harness,
korzystające ze wspólnej biblioteki shell w `.chezmoitemplates/`; (4) lock/acceptance record dla rewizji `25d785a`
tam, gdzie CLI nie umie pinu; (5) testy na stubach CLI + opcjonalny smoke natywny.

**Stack:** chezmoi 2.73.1 (szablony Go, `.chezmoidata`, `run_onchange_`), bash, PowerShell (Windows, osobny PR), CLI:
Claude Code 2.1.314, Codex 0.164.0, OpenCode 2.2.0 (tylko wykryty, nie używany).

## Global Constraints

- Profil + topologia domyślnie `STANDARD + SOLO`; `dotfiles` **nie** ustawia ani nie kopiuje profilu/topologii/lifecycle.
- `claude-plugins` jest właścicielem lifecycle, profili i topologii; `dotfiles` tylko dystrybuuje i konfiguruje.
- Worktree-first: primary checkout czysty na `main`; prace w `.worktrees/<type>/<slug>`; `.worktrees/` w `.git/info/exclude`.
- Superpowers opcjonalny (tylko profil `claude-extended`); wyłączenie go nie blokuje żadnego etapu.
- Brak jednego harnessu (CLI) nie przerywa konfiguracji pozostałych ani całego `chezmoi apply`.
- Żadnego automatycznego odinstalowywania pluginów; zmiana profilu = co najwyżej wyłączenie, usuwanie ręcznie.
- Żadnych tokenów/wartości prywatnych w renderowanych konfiguracjach.
- Historyczne dokumenty `docs/superpowers/**` nie są migrowane ani przepisywane.
- Brak automatycznej delegacji: żadna konfiguracja nie uruchamia subagentów/agent teams domyślnie dla nowych hostów.
- PR-1 nie zmienia zachowania istniejących hostów (render `settings.json` i efekt `apply` bez zmian), ale ustanawia jawny default `core` dla nowych inicjalizacji.
- Nowy vs istniejący host rozróżnia `chezmoi init` po istnieniu pliku konfiguracji (`.chezmoi.configFile`), **nie** po samym braku klucza `ai_profile`; po `init` klucze `ai_*` są zawsze zapisane jawnie.
- `minimal` zachowuje kanoniczny lifecycle i worktree-first (instaluje `git-workflows` + `development-lifecycle`); profil bez żadnych pluginów (`bare`) jest tylko zarezerwowany i **nie** jest implementowany.

## Review Focus

Niepokryte wprost przez spec, a najbardziej prawdopodobne w użyciu (każdy ma test w wskazanym zadaniu):

1. Istniejący host **bez** klucza `ai_profile`: (a) zwykły `chezmoi apply` nie może się wywrócić i daje dotychczasowy zestaw, (b) ponowny `chezmoi init`
   nie może po cichu przestawić go na `core` (T03, T04). Nowy host dostaje jawne `core` + `ai_agent_teams=false` (T03).
2. `run_onchange_` oznaczony jako wykonany, gdy CLI nie było (odcisk z `lookPath` to rozwiązuje) **albo gdy operacja się nie powiodła** (exit 0 po `WARN`) — powtórka wymaga kontrolowanego, ręcznego resetu stanu jednego skryptu, nigdy `delete-bucket scriptState` (T05, T06, T08, T09, T13).
3. `claude plugin marketplace add` z innym źródłem niż wpis `extraKnownMarketplaces` jest odrzucany (zmierzone) — zmiana
   źródła/refa w jednym miejscu bez drugiego psuje instalację (T06, T10).
4. Windows dostaje dziś `run_once_install-claude-plugins.sh` (brak wpisu w `.chezmoiignore`) — apply nie może się wysypać (T10).
5. Sieć niedostępna / marketplace niedostępny: skrypt kończy się ostrzeżeniem, nie blokuje apply, a doctor pokazuje stan (T06, T08, T09).
6. `chezmoi init` bez TTY (devcontainer, CI): `--no-tty` kończy się błędem, nieinteraktywnie działa tylko `--promptDefaults`; flagi `--promptChoice`/`--promptBool` są kluczowane **tekstem promptu**, nie nazwą klucza (T03, T13).

---

## 1. Audit repozytorium (stan `96a0802`)

Repo: `.chezmoiroot` → `home/`; brak `.github/`, `.devcontainer/`, testów, `README`, `AGENTS.md`/`CLAUDE.md`. Dokumentacja:
tylko `docs/superpowers/{specs,plans}` (3 pliki, 2026-05-15, format Superpowers, historyczne). Brak neutralnej bieżącej
konwencji → używamy `docs/plans/<slug>/{plan,tasks}.md` (zgodnie z `claude-plugins`).

### 1.1 Skrypty chezmoi

| Plik | Co robi | Tools |
| --- | --- | --- |
| `home/run_once_install-claude-plugins.sh` | rejestruje `mmalyska/claude-plugins` i `anthropics/claude-plugins-official`, instaluje 12 własnych pluginów + `superpowers`, `code-simplifier`, `context7`, `claude-md-management` | Claude |
| `home/.chezmoiscripts/devcontainer/run_once_000-peon-ping.sh` | `curl … main/install.sh \| bash` (peon-ping, hooki Claude) | Claude (hooki) |
| `home/.chezmoiscripts/macos/run_onchange_000-packages.sh.tmpl` | `brew install --cask claude`, `--cask claude-code`, gh, ghostty, VS Code, peon-ping; work: slack, docplanner | Claude Code CLI (cask) |
| `home/.chezmoiscripts/macos/run_once_before_000-homebrew.sh` | instalacja Homebrew (`curl \| bash`) | — |
| `home/.chezmoiscripts/linux/run_onchange_000-packages.sh` | pacman/paru: `claude-desktop-bin` (desktop, **nie CLI**), nodejs, npm itd. | Claude Desktop |
| `home/.chezmoiscripts/linux/run_once_before_000-bootstrap.sh` | paru | — |
| `home/.chezmoiscripts/linux/run_once_00{1,2,3}-*.sh` | ASUS / KVM / power profiles | — |
| `home/.chezmoiscripts/windows/run_onchange_000-packages.ps1.tmpl` | winget: `Anthropic.Claude` (desktop), gh, VS Code; peon-ping `install.ps1` | Claude Desktop |

Codex: **brak** jakiegokolwiek skryptu, pakietu ani konfiguracji. OpenCode: brak. `home/dot_codex/**`: nie istnieje.
`home/dot_claude/**`: tylko `settings.json.tmpl` i `statusline/settings.json`.

### 1.2 Konfiguracje i warianty platformowe

- `.chezmoi.toml.tmpl`: dane `email`, `user`, `is_work` (prompt), `is_wsl`, `is_arch`, `is_devcontainer` (username `vscode` albo env
  `REMOTE_CONTAINERS`/`CODESPACES`/`DEVCONTAINER`). Płaskie klucze `snake_case`. Brak jakichkolwiek danych AI.
- `.chezmoiignore`: wycina `.chezmoiscripts/<os>/*` dla innych OS; w devcontainerze wycina wszystkie skrypty OS i zostawia
  `devcontainer/*`; **nie** wspomina `run_once_install-claude-plugins.sh`, więc skrypt `.sh` leci też na Windows i poza devcontainerem
  na każdym OS.
- `settings.json.tmpl` (w całości zarządzany przez chezmoi → każdy `apply` nadpisuje plik, także zmiany, które robi sam Claude):
  - l.3 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` bezwarunkowo; `model: opusplan`; `MAX_THINKING_TOKENS`, autocompact;
  - hooki peon-ping na 9 zdarzeniach (m.in. `SubagentStart`, l.47) — zależą od `~/.claude/hooks/peon-ping/` (instalowanego tylko w devcontainer/macOS/Windows);
  - l.159 `enabledPlugins`: 4 oficjalne (w tym `superpowers`) + 12 własnych — twardo wpisane;
  - l.181 `extraKnownMarketplaces`: oficjalny + `mmalyska/claude-plugins` bez `ref`.
- `~/.codex/config.toml` (poza chezmoi): `model = "gpt-6.1-sol"`, `reasoning low`, zaufane projekty, wpisy `[marketplaces.*]`/`[plugins.*]`
  zapisywane przez `codex plugin …`. **Nie wolno** go zarządzać jako pliku w całości.

### 1.3 Wyniki pomiarów CLI (izolowane `CLAUDE_CONFIG_DIR`/`CODEX_HOME` w scratchpadzie; `~/.claude`, `~/.codex` nietknięte)

| Pytanie | Wynik |
| --- | --- |
| Codex: pin marketplace do SHA | **TAK.** `codex plugin marketplace add mmalyska/claude-plugins --ref <sha>` (i `…@<sha>`) zapisuje w `config.toml` `ref = "<sha>"`; powtórzenie → exit 0 „already added" |
| Codex: idempotencja `plugin add` | dwukrotne `codex plugin add git-workflows@mmalyska-claude-plugins` → exit 0 oba razy; nieistniejący plugin → błąd z kodem ≠ 0 |
| Codex: pin samego pluginu | brak flagi; wersja wynika z rewizji marketplace (po `--ref 25d785a` zainstalowało `git-workflows` 1.3.10) |
| Claude: `marketplace add owner/repo#<sha>` | **NIE.** `git clone --branch` odrzuca SHA: `Remote branch <sha> not found in upstream origin`. Wersja z `#<sha>` próbuje też SSH („Host key verification failed") |
| Claude: `marketplace add owner/repo` | działa; bez SSH sam przechodzi na HTTPS („SSH not configured, cloning via HTTPS") |
| Claude: tagi/branche jako ref | nie testowane — w `claude-plugins` **nie ma tagów** (`gh api …/tags` puste); `25d785a` jest dziś HEAD `main` |
| Claude: pin pluginu / `install` | brak flagi ref/version w `install`/`update`; `marketplace update` nie ma opcji rewizji (aktualizuje do najnowszej) |
| Claude: źródło vs `extraKnownMarketplaces` | `marketplace add` z innym źródłem niż wpis w settings kończy się `failureCode: declared` — źródło musi być identyczne |
| Claude: `extraKnownMarketplaces.…source.ref = <sha>` | **nierozstrzygnięte** (próba zakończona błędem źródła, patrz wyżej) — spike S1 w T06 |

Wniosek o pinie: Codex — pin natywny do SHA. Claude — SHA nieobsługiwany; pozostaje (a) tag/branch po utworzeniu tagu w
`claude-plugins` (zadanie zewnętrzne T14), (b) **lock + acceptance record + weryfikacja dryfu + kontrolowany upgrade**.
Plan implementuje (b) od razu (działa bez zmian w innym repo) i przechodzi na (a) tylko po dowodzie.

### 1.4 Wyniki pomiarów chezmoi 2.73.1 (rev. 2; izolowane katalogi w scratchpadzie)

| Pytanie | Wynik |
| --- | --- |
| `home/.chezmoidata/*.yaml` ładowane jako `.ai_workflow…` w szablonach | **TAK** (`{{ .ai_workflow.marketplace.own.accepted_sha }}` → wartość; `len` listy działa); zepsuty YAML → głośny błąd parsowania z numerem linii. Z `.chezmoiroot` katalogiem źródłowym jest `home/` (`.chezmoi.sourceDir`). Plik danych jeszcze nie istnieje — test T02 dowodzi ładowania na prawdziwym pliku, a nie na założeniu |
| Plik źródłowy doctora | `executable_ai-workflow-doctor` → cel `ai-workflow-doctor` (0755). `executable_….tmpl` → cel bez `.tmpl`, szablon wykonany. **`….tmp` NIE jest rozszerzeniem chezmoi** — trafia do celu dosłownie jako `ai-workflow-doctor3.tmp` |
| Nieinteraktywny `init` | `--promptDefaults` → wartości domyślne. `--no-tty` → błąd `EOF`/brak TTY. Bez żadnej flagi i bez TTY → błąd `could not open a new TTY` |
| Flagi odpowiedzi | `--promptChoice "<tekst promptu>=<wartość>"`, `--promptBool "<tekst promptu>=<bool>"`; klucz = **tekst promptu** (np. `--promptChoice ai_profile=minimal` nie jest dopasowane: bez TTY kończy się błędem, z `--promptDefaults` daje domyślne `core`) |
| `prompt*Once` przy istniejącym kluczu | zwraca zapisaną wartość i **ignoruje** flagę; zmiana wymaga `--prompt` (wtedy flaga działa) albo edycji `[data]` w pliku konfiguracji |
| `.chezmoi.configFile` + `stat` w `.chezmoi.toml.tmpl` | `stat` zwraca `false` na nowym hoście i `true`, gdy plik konfiguracji już istnieje (również bez klucza `ai_profile`); `hasKey . "ai_profile"` jest `false` dla konfiguracji sprzed zmiany |
| Stan `run_onchange_` vs `run_once_` | `run_once_` → `scriptState` (klucz = sha256 treści); `run_onchange_` → `entryState` (klucz = ścieżka docelowa, np. `<dest>/.chezmoiscripts/ai/100-a.sh`, wartość `contentsSHA256`). Skrypt z exit 0 po błędzie nie jest powtarzany przy kolejnym `apply` |
| Reset jednego skryptu | `chezmoi state delete --bucket=entryState --key=<ścieżka docelowa>` + `chezmoi apply` → uruchamia się **tylko** ten skrypt; kolejny `apply` bez zmian — zero uruchomień. `state delete-bucket --bucket=scriptState` NIE ruszył `run_onchange_` (uruchomił tylko `run_once_`) |
| Zachowanie wzorca „legacy-aware" | nowy host + `--promptDefaults` → `core`/`false`; istniejący bez klucza + `init` → jawnie `claude-extended`/`true` bez pytania; kolejny `init` stabilny; `init --prompt --promptChoice "AI profile=core" --promptBool "Enable Claude agent teams=false"` → `core`/`false` |

Konsekwencja: naiwne `promptChoiceOnce … "core"` zapisałoby `core` także na istniejącym hoście przy pierwszym ponownym `chezmoi init` — ryzyko R11, wykluczone projektem D-G.

## 2. Wykryte konflikty ze zaakceptowanym workflow

| # | Konflikt | Miejsce | Skutek | Rozwiązanie (zadanie) |
| --- | --- | --- | --- | --- |
| C1 | Superpowers instalowany i włączany obowiązkowo | `run_once_install-claude-plugins.sh:21`, `settings.json.tmpl:160` | `core` nie istnieje; wyłączenie Superpowers wymaga edycji repo | profile + `claude_extras` tylko w `claude-extended` (T02, T04, T06) |
| C2 | Brak wsparcia Codex | brak plików | Codex dostaje tylko ręczną konfigurację | `run_onchange_after_110-codex-plugins` + pin `--ref` (T08) |
| C3 | Instalacja przerywa się bez CLI | `set -euo pipefail` + gołe `claude plugin …` (l.2–17, 20) | brak `claude` → błąd → `chezmoi apply` zatrzymany, w tym dla Codex/reszty | `ai_have` + SKIP, exit 0, ponowne uruchomienie po pojawieniu się CLI (T05, T06) |
| C4 | Nieidempotentność / ukryte błędy | `\|\| true` na `marketplace add` maskuje realny błąd; `marketplace update` zawsze, bez warunku; `run_once_` = nigdy ponownie po zmianie listy | dryf wersji (update przesuwa do najnowszej = niezgodne z zaakceptowaną rewizją), brak retry po awarii | check-before-add/install, `run_onchange_`, bez automatycznego update (T06) |
| C5 | Duplikowanie listy pluginów | ta sama lista 16 pluginów w skrypcie **i** w `enabledPlugins`/`extraKnownMarketplaces` | rozjazd przy każdej zmianie | jedno źródło: `.chezmoidata/ai-workflow.yaml` (T02, T04, T06) |
| C6 | Wymuszony agent teams | `settings.json.tmpl:3` | sprzeczne z „brak automatycznej delegacji" dla nowych hostów | flaga `ai_agent_teams`, domyślnie `false`; `true` tylko dla hostów legacy (T03, T04) |
| C7 | Różne defaulty między harnessami | Claude: `opusplan`, thinking tokens, `alwaysThinkingEnabled`; Codex: `gpt-6.1-sol`, effort `low` | brak wspólnego defaultu *modelu* | świadomie **nie unifikujemy modeli**; wspólny jest tylko default workflow (`STANDARD + SOLO`) pochodzący z pluginu; test, że `dotfiles` go nie nadpisuje (T04, T13) |
| C8 | Brak pinu zaakceptowanej rewizji | `extraKnownMarketplaces` bez `ref`; `marketplace update` do HEAD | host dostaje niezaakceptowany kod | lock + weryfikacja + runbook upgrade (T02, T06, T09, T11) |
| C9 | `run_once_*.sh` w korzeniu `home/` bez gałęzi OS/devcontainer | `.chezmoiignore` | Windows próbuje uruchomić `.sh`; brak odpowiednika PowerShell | wpis ignore + `ps1` (T10) |
| C10 | Nieaktualne dokumenty historyczne jako bieżące | `docs/superpowers/plans/2026-05-15-claude-marketplace-scaffold.md` m.in. opisuje kopiowanie z `~/.local/share/chezmoi/home/dot_claude/` (już nie istnieje) | nowa sesja może to wykonać jako instrukcję | **nie edytujemy** treści; dodajemy `docs/README.md` oznaczający je jako historyczne (T11) |
| C11 | Niepinowane `curl \| bash` | peon-ping (`main`), Homebrew (`HEAD`) | poza zakresem workflow; wpływa na reprodukowalność | tylko odnotowane (ryzyko R7), bez zmian |
| C12 | Pakiety CLI niepełne | macOS: `claude-code` cask, brak Codex; Linux/Windows: tylko aplikacja Desktop, brak CLI | „brak CLI" jest stanem normalnym na części hostów | instalacja CLI osobna i opcjonalna (T08), pakiety do weryfikacji, nie zgadywać nazw |
| C13 | Naiwny prompt `core` przy ponownym `init` zmieniłby istniejący host | (projektowe) | cicha migracja profilu | D-G: wykrywanie istniejącej konfiguracji + jawny zapis `claude-extended`/`true` (T03) |

Niewykryte (sprawdzone): brak automatycznej delegacji/orkiestratora w skryptach; brak kopii skills/lifecycle w repo.

## 3. Decyzje projektowe

**D-A. Profile** (dane chezmoi `ai_profile`; wybór przy `chezmoi init`):

| Profil | Własne pluginy (`mmalyska-claude-plugins`) | Dodatki Claude (`claude-plugins-official`) | Codex |
| --- | --- | --- | --- |
| `minimal` | tylko `git-workflows`, `development-lifecycle` | brak | te same 2, jeśli `ai_codex` i CLI jest |
| `core` (domyślny dla nowych inicjalizacji) | pełny zestaw 12 z `mmalyska/claude-plugins` (jak dotychczasowy skrypt) | brak | te same 12 |
| `claude-extended` (hosty istniejące) | jak `core` | `superpowers`, `code-simplifier`, `context7`, `claude-md-management` (opcjonalne, tylko Claude) | jak `core` — **nigdy** dodatki Claude |

`minimal ⊂ core ⊂ claude-extended`. `minimal` zachowuje kanoniczny lifecycle (`development-lifecycle`) i worktree-first (`git-workflows`: reguła + hook Claude).
Profil bez żadnych pluginów (`bare`) jest tylko **zarezerwowaną nazwą**: nie ma go na liście wyboru, nie jest implementowany, a test (T03) dowodzi,
że `ai_profile = "bare"` kończy się błędem `unknown ai_profile`. Do zrobienia osobno, jeśli kiedyś potrzebny.

Dodatkowe, ortogonalne dane: `ai_claude` (bool, `true`), `ai_codex` (`true`), `ai_opencode` (`false`, niezużywane do czasu spike'u),
`ai_agent_teams` (`false` dla nowych; zachowane/`true` dla legacy). Wszystkie zapisywane **jawnie** przez `chezmoi init` (D-G).

**D-B. Gdzie co leży**

- `home/.chezmoidata/ai-workflow.yaml` — statyczne: marketplace (nazwa, repo, `accepted_sha`, `accepted_tag`), listy pluginów (`plugins.workflow` = 2, `plugins.own` = 12, `plugins.claude_extras` = 4), mapowanie profil → zestawy. Ładowanie dowodzone testem na prawdziwym pliku (T02), nie założeniem — patrz §1.4.
- `home/.chezmoi.toml.tmpl` — tylko wybory użytkownika (`ai_*`), z logiką D-G.
- `home/.chezmoitemplates/ai-profile.tmpl` — rozwiązanie profilu w czasie `apply` (walidacja + przejściowy fallback dla konfiguracji sprzed zmiany); `ai-lib.sh` — wspólne funkcje shell.
- Doctor: `home/dot_local/bin/executable_ai-workflow-doctor.tmpl` (**`.tmpl`**, bo czyta `accepted_sha`, profil i flagi z danych; cel: `~/.local/bin/ai-workflow-doctor`). Zweryfikowane: `.tmp` nie jest rozszerzeniem chezmoi; wariant bez szablonu (`executable_ai-workflow-doctor`) byłby poprawny tylko gdyby skrypt nie potrzebował danych.
- `home/.chezmoiscripts/ai/` — skrypty per harness (jeden katalog, ignorowany na Windows dopóki nie ma `ps1`).
- `tests/ai/` — testy; `docs/workflow/acceptance.md` — rejestr zaakceptowanych rewizji.
- Brak `home/dot_codex/**`: Codex zarządzamy wyłącznie przez CLI (`codex plugin …`); `config.toml` jest mutowany przez Codex.
  Jeśli kiedyś potrzebna będzie stała konfiguracja → `modify_` script scalający, osobna decyzja.

**D-C. Instalatory:** `run_onchange_after_` (a nie `run_once_`), render zawiera komentarz-odcisk: profil, flagi, `accepted_sha`,
listy pluginów **oraz** `lookPath "claude"`/`"codex"` (present/absent) — dzięki temu zmiana danych albo pojawienie się CLI
powoduje ponowne uruchomienie. Każdy skrypt: brak CLI ⇒ komunikat `SKIP` i exit 0; błąd pojedynczej operacji ⇒ `WARN`,
kontynuacja, exit 0 (żeby nie blokować innych harnessów); podsumowanie w ostatniej linii oraz trwały zapis wyniku w pliku statusu
(`${XDG_STATE_HOME:-$HOME/.local/state}/ai-workflow/<harness>.status`: `result=ok|partial|skipped`, `fails=<n>`, `accepted_sha`, czas).

**D-C1. Recovery po błędzie instalacji — retry jest MANUALNY (nie ma automatycznego retry).** Zmierzone (§1.4): skrypt kończący się exit 0 po błędzie jest dla chezmoi „wykonany";
kolejny `apply` go nie powtórzy, dopóki nie zmieni się jego wyrenderowana treść. Dlatego: (1) wynik jest zapisany w pliku statusu, (2) `ai-workflow-doctor --strict` wykrywa `partial`
(exit 1) i **drukuje** (nie wykonuje) dokładną komendę resetu, (3) użytkownik resetuje stan **jednego** skryptu, (4) `chezmoi apply` go powtarza.
Przebieg: `failure → ai-workflow-doctor --strict (exit 1 + komenda) → chezmoi state delete --bucket=entryState --key="<destDir>/.chezmoiscripts/ai/<nn>-<harness>-plugins.sh" → chezmoi apply → ai-workflow-doctor --strict (exit 0)`.
Klucz = ścieżka docelowa skryptu (np. `$HOME/.chezmoiscripts/ai/100-claude-plugins.sh`; prefiksy `run_onchange_after_` i `.tmpl` są zdjęte), doctor składa go z `.chezmoi.destDir` w czasie renderu.
**Zakazane w dokumentacji i testach:** `chezmoi state delete-bucket --bucket=scriptState` (zmierzone: nie resetuje skryptów `run_onchange_`, bo ich stan jest w `entryState`, za to uruchomiłby ponownie
wszystkie skrypty `run_once_`, m.in. `sudo`/`pacman` w `.chezmoiscripts/linux/`) oraz `chezmoi state reset` / `delete-bucket --bucket=entryState` (kasują stan wszystkich skryptów i plików). Przed resetem doctor
wypisuje ostrzeżenie, co dokładnie zostanie powtórzone (jeden skrypt) i że reszta `apply` przebiegnie normalnie (zmienione pliki zostaną zastosowane, jak przy każdym `apply`; podgląd: `chezmoi apply --dry-run --verbose`).

**D-D. Pin:**

- Codex: `codex plugin marketplace add mmalyska/claude-plugins --ref <accepted_sha>`; jeśli już dodany z innym refem — procedura upgrade (T11), nie automat.
- Claude: `claude plugin marketplace add mmalyska/claude-plugins` (źródło identyczne z `extraKnownMarketplaces`), **bez** automatycznego `marketplace update`;
  odczyt rewizji z `${CLAUDE_CONFIG_DIR:-~/.claude}/plugins/marketplaces/mmalyska-claude-plugins` (`git rev-parse HEAD`) i porównanie z `accepted_sha`
  ⇒ `WARN drift` (skrypt) / `DRIFT` (doctor). Upgrade tylko jawnie: `AI_WORKFLOW_UPGRADE=1 chezmoi apply` po zmianie `accepted_sha` w PR.
- Acceptance record: `docs/workflow/acceptance.md` — SHA, data, wersje CLI, wynik testów, link do specyfikacji, kto zaakceptował.
- Tag: **`ai-workflow-v0.1.0-preview.1`** ma wskazywać dokładnie `25d785abee26ca7a3c87e8311f46e8a90f225301`. Kolejność jest wiążąca: (1) T06/S1 testuje empirycznie, czy Claude Code
  przyjmuje `owner/repo#tag` i czy `extraKnownMarketplaces.source.ref` obsługuje tag — na **lokalnym** repozytorium git z lokalnym tagiem w scratchpadzie (bez tworzenia tagu w GitHub);
  (2) tag w `claude-plugins` powstaje **wyłącznie na osobne polecenie** użytkownika (T14); (3) dopiero potem `accepted_tag` w danych i `pin_mode: tag`.
  Jeśli S1 wykaże, że Claude nie obsługuje pinu tagiem — zostaje `pin_mode: verify` (acceptance record + doctor + kontrolowany upgrade); tag nadal jest użyteczny dla Codex (`--ref`) i jako czytelna etykieta.

**D-E. Shared default bez kopiowania:** `dotfiles` nie zawiera słów `STANDARD`, `SOLO`, nazw etapów ani ścieżek procedur w żadnym
renderowanym pliku. Default pochodzi z `development-lifecycle` (contract `rules/common/workflow.md`) na zaakceptowanej rewizji.
Test T04/T13 sprawdza brak takich ciągów i brak kluczy topologii w settings/`config.toml`.

**D-G. Rozróżnienie hosta nowego od istniejącego (zmierzone, §1.4)**

Sam brak klucza `ai_profile` **nie** jest sygnałem „istniejący host" (nowy host też go nie ma przed pierwszym `init`). Sygnałem jest **istnienie pliku konfiguracji
chezmoi** w momencie renderowania `.chezmoi.toml.tmpl`: `$existing := stat .chezmoi.configFile`. Logika (szkic, nie implementacja):

```text
legacyHost := $existing AND NOT hasKey(., "ai_profile")
legacyHost : ai_profile = "claude-extended"; ai_agent_teams = true      # zapisane jawnie, BEZ pytania
inaczej    : ai_profile = promptChoiceOnce(…, default "core")            # nowy host albo klucz już zapisany
             ai_agent_teams = promptBoolOnce(…, default false)
```

| Sytuacja | Wynik | Gdzie testowane |
| --- | --- | --- |
| nowy host, `chezmoi init --promptDefaults` | jawnie `ai_profile = "core"`, `ai_agent_teams = false` | T03 |
| nowy host, `--promptChoice "AI profile=minimal"` | `minimal` | T03 |
| istniejący host bez klucza, `chezmoi apply` (bez `init`) | `ai-profile.tmpl`: przejściowy fallback `claude-extended` + `agent_teams=true`; render == golden | T03, T04 |
| istniejący host bez klucza, `chezmoi init` (także `--promptDefaults`, także bez TTY) | jawnie `claude-extended`/`true`, **bez pytania** (brak nowego pytania na istniejących hostach), kolejny `init` stabilny | T03 |
| migracja po pierwszym świadomym wyborze | `chezmoi init --prompt --promptChoice "AI profile=core" --promptBool "Enable Claude agent teams=false"` lub edycja `[data]` w pliku konfiguracji → `core`/`false`; `enabledPlugins` traci wpisy dodatków, brak jakiegokolwiek `uninstall` | T03, T07 |
| ponowny `init` po wyborze | wybór zachowany (`Once`) | T03 |
| nieznany profil / `bare` | błąd `unknown ai_profile` przy renderze | T03 |

Fallback w `ai-profile.tmpl` jest zatem wyłącznie zabezpieczeniem dla `apply` na hoście, który nie wykonał jeszcze `init` po tej zmianie; każda konfiguracja
wygenerowana nowym szablonem ma klucze jawnie. Znane granice: ręcznie założony plik konfiguracji bez `ai_profile` na „nowej" maszynie zostanie uznany za istniejący host
(wybór świadomy przez `--prompt`); teksty promptów są częścią kontraktu z flagami `--promptChoice/--promptBool` (R12) i są stałymi w `tests/ai/lib.sh`.

**D-H. `settings.json` i zapisy CLI Claude (rev. 2 po PR-5).** `settings.json` pozostaje w pełni zarządzany przez chezmoi. Prawdziwe `claude plugin install` przepisuje ten plik (ta sama treść, inna kolejność kluczy),
przez co zwykły drugi `chezmoi apply` kończył się konfliktem „has changed since chezmoi last wrote it". Spike `run_onchange_before_` przeszedł dla świeżego hosta, ale padał na hoście istniejącym, gdy instalator coś instaluje
(zmiana profilu) — odrzucone. Przyjęte: instalator Claude (Bash i PowerShell, nadal `run_onchange_after_`) robi snapshot dokładnych bajtów i uprawnień `settings.json` przed pierwszą komendą mutującą i zawsze go przywraca
(atomowo; plik utworzony przez CLI usuwa; błąd snapshotu lub przywrócenia = `partial`). Nazwa skryptu i klucz `entryState` bez zmian. Dowody: `docs/workflow/evidence/T13-e2e.md`.

**D-F. OpenCode:** wyłącznie dane `ai_opencode: false` + dokument spike'u (T12). `opencode` jest wykrywany przez doctor
(informacyjnie). Brak instalatora, brak wymogu.

## 4. Docelowa struktura

```text
home/
  .chezmoi.toml.tmpl                      # + ai_profile, ai_claude, ai_codex, ai_opencode, ai_agent_teams
  .chezmoiignore                          # + ai/* wg OS (T10); w PR-1 bez zmian
  .chezmoidata/ai-workflow.yaml           # NOWE: marketplace lock + zestawy pluginów + profile
  .chezmoitemplates/
    ai-profile.tmpl                       # NOWE: walidacja profilu + przejściowy fallback dla konfiguracji sprzed zmiany
    ai-lib.sh                             # NOWE: ai_have/ai_log/ai_soft/…
  .chezmoiscripts/ai/
    run_onchange_after_100-claude-plugins.sh.tmpl     # NOWE (zastępuje home/run_once_install-claude-plugins.sh)
    run_onchange_after_110-codex-plugins.sh.tmpl      # NOWE
    run_onchange_after_100-claude-plugins.ps1.tmpl    # NOWE w T10 (Windows)
    run_onchange_after_110-codex-plugins.ps1.tmpl     # NOWE w T10
  dot_claude/settings.json.tmpl           # profil-zależny (env, enabledPlugins, extraKnownMarketplaces)
  dot_local/bin/executable_ai-workflow-doctor.tmpl    # NOWE: tylko odczyt (T09)
tests/ai/ run.sh, lib.sh, stubs/{claude,codex}, fixtures/*.toml, golden/*.json, test_*.sh
.github/workflows/ai-tests.yml          # NOWE w PR-1: CI Linux (offline, chezmoi przypięty do 2.73.1)
docs/
  README.md                               # NOWE: oznaczenie dokumentów historycznych
  workflow/acceptance.md, workflow/upgrade-runbook.md, workflow/opencode-spike.md
  plans/hybrid-ai-workflow-dotfiles/{plan,tasks}.md
  superpowers/**                          # BEZ ZMIAN
```

## 5. Migracja istniejących hostów (bez odinstalowywania)

1. **PR-1 nie zmienia efektu na hostach istniejących.** `chezmoi apply` bez `init`: brak klucza `ai_profile` ⇒ przejściowy fallback (`claude-extended`, `ai_agent_teams=true`),
   render `settings.json` identyczny z golden z `96a0802`. Zaraz po `chezmoi init` (dowolnym, także `--promptDefaults`, także bez TTY) host dostaje te same wartości **jawnie** w pliku konfiguracji (D-G).
2. Stary `run_once_install-claude-plugins.sh` znika (PR-2, T07). Chezmoi niczego nie usuwa z `$HOME` — zainstalowane pluginy zostają. Nowy `run_onchange_` uruchomi się raz,
   sprawdzi stan i na w pełni zainstalowanym hoście nie wykona żadnej operacji mutującej (test T06c/T07).
3. Świadoma migracja profilu: `chezmoi init --prompt --promptChoice "AI profile=core" --promptBool "Enable Claude agent teams=false"` albo edycja `[data]` w `~/.config/chezmoi/chezmoi.toml`.
   `claude-extended → core` usuwa wpisy `enabledPlugins` dodatków (Superpowers przestaje być włączony), **nie** wykonuje `plugin uninstall`; usunięcie ręcznie (runbook, T11b).
   `core → minimal` analogicznie wyłącza 10 pluginów w `enabledPlugins`, nic nie odinstalowuje.
4. `chezmoi apply` nadpisuje `~/.claude/settings.json` — zmiany zrobione przez Claude (np. `/config`) znikają; backup przed pierwszym apply (T11b).
5. Codex: na hostach z `codex` pierwszy apply po PR-3 doda marketplace (z `--ref`) i pluginy profilu — jedyna *nowa* zmiana widoczna dla użytkownika Codex; wyłączalna `ai_codex=false`.

## 6. Rollback (ogólnie; szczegóły per zadanie)

- Każdy PR to czysty `git revert`; po revert `chezmoi apply` przywraca poprzedni render. Brak zmian w `$HOME` wykonywanych poza chezmoi.
- Przed pierwszym apply nowej wersji: kopia `~/.claude/settings.json`, `~/.codex/config.toml`, `claude plugin list --json`, `codex plugin list` w `~/.local/state/ai-workflow-backup/<data>/` (T11b).
- Klucze `ai_*` zapisane przez `chezmoi init` w pliku konfiguracji są po revert nieszkodliwe (nieużywane dane).
- Plugin zainstalowany przez nową wersję nie jest usuwany automatycznie; cofnięcie wersji pluginu = przywrócenie poprzedniego `accepted_sha` + procedura upgrade/downgrade.
- Stop condition: apply kończący się błędem na hoście legacy; render legacy różny od golden; plugin Superpowers dezaktywowany bez zmiany profilu; CI PR-1 czerwone.

## 7. Strategia testów

- **Poziom 1 (offline, deterministyczny; lokalnie i w CI):** `tests/ai/run.sh`:
  - dane i szablony: `chezmoi data`/`execute-template` na prawdziwym `home/.chezmoidata/ai-workflow.yaml` (dowód ładowania), walidacja kształtu danych;
  - rendery `minimal`, `core`, `claude-extended` oraz hosta legacy (golden) — fixtures `--config`;
  - `chezmoi init` na **kopii** drzewa repo w katalogu tymczasowym z `--promptDefaults`/`--promptChoice "<tekst>=…"`: nowy host, istniejący host, migracja;
  - skrypty uruchamiane z `PATH` ze stubami `claude`/`codex` (log wywołań): tylko Claude, tylko Codex, oba, żaden; drugie uruchomienie = zero wywołań mutujących;
  - skan sekretów i brak ciągów workflow (`STANDARD|SOLO|…`) w renderach; **brak zmian poza repo/tmp**: `HOME` ustawiony na katalog tymczasowy, snapshot (`find`) katalogu rzeczywistego `$HOME` przed/po oraz `git status --porcelain` puste.
- **CI (PR-1, Linux):** `.github/workflows/ai-tests.yml` uruchamia poziom 1 na `ubuntu-latest` z chezmoi `v2.73.1` (zweryfikowana wersja), bez `claude`/`codex`, z `permissions: contents: read`;
  `shellcheck` dla `tests/ai/*.sh` i szablonów powłoki (gdy pojawią się). Wszystkie testy ze stubami (w tym brak CLI w PATH, `ai_claude/ai_codex=false`, brak sieci symulowany stubem, przebieg recovery) są wykonywalne w CI i **muszą dać PASS**; `NOT RUN` dotyczy wyłącznie testów natywnych. Windows i macOS dochodzą z ich instalatorami (PR-4).
- **Poziom 2 (natywny, opt-in `AI_NATIVE_TESTS=1`):** prawdziwe CLI z tymczasowym `CLAUDE_CONFIG_DIR` i `CODEX_HOME` (poza `/tmp`, bo Codex odmawia aliasów w `/tmp`; użyć `$HOME/.cache/ai-workflow-test.*`), bez tur modelu. `NOT RUN` (z przyczyną) wolno użyć **tylko** gdy brakuje prawdziwego CLI, platformy, sieci albo zewnętrznego serwisu wymaganego przez test natywny; scenariusze, które można zasymulować stubem, są testami poziomu 1 i nie mogą być `NOT RUN`. `NOT RUN` nigdy nie jest PASS.
- **Poziom 3 (świeże środowisko):** `chezmoi init --apply --promptDefaults` w czystym `HOME` → ponowny `chezmoi apply` → `chezmoi diff` pusty i zero wywołań mutujących (T13).

## 8. Podział na PR-y (kolejność rev. 2)

| PR | Zawartość | Zadania | Zależy od |
| --- | --- | --- | --- |
| PR-0 | ten plan (docs only) | — | — |
| **PR-1** | harness testów **+ CI Linux**, dane + profile (`minimal`/`core`/`claude-extended`), logika `init` D-G (jawny default `core` dla nowych), settings sterowany profilem z golden testem hosta legacy, rekord akceptacji, `docs/README.md`; **zero zmian zachowania na hostach istniejących** | T00, T01, T02, T03, T04, T04a, T11a | PR-0 |
| PR-2 | instalator Claude (soft-fail, idempotentny, verify pinu), spike S1 (evidence), usunięcie starego `run_once` | T05–T07 | PR-1 |
| PR-3 | instalator Codex + CLI packages (po weryfikacji nazw) + doctor | T08–T09 | PR-2 (ai-lib) |
| PR-4 | Windows/macOS CI, ps1, `.chezmoiignore` | T10 | PR-3 |
| PR-5 | runbook upgrade/rollback, spike OpenCode (doc), E2E świeże środowisko | T11b, T12, T13 | PR-4 |
| (zewn.) | tag `ai-workflow-v0.1.0-preview.1` w `claude-plugins` — **dopiero po S1 i osobnym poleceniu** | T14 | S1 z PR-2 |

Każdy PR niezależnie odwracalny; PR-2+ nie zmieniają renderu settings (to w PR-1).

## 9. Ryzyka migracji hostów

| ID | Ryzyko | Prawdop. | Skutek | Mitigacja |
| --- | --- | --- | --- | --- |
| R1 | Template wywraca się na hoście bez `ai_*` (apply bez init) | wysokie bez fallbacku | `apply` pada na wszystkich hostach | przejściowy fallback w `ai-profile.tmpl`, golden legacy, test „brak kluczy" (T03/T04) |
| R2 | `settings.json` nadpisany, tracone zmiany z `/config` | pewne (istniejące zachowanie) | utrata lokalnych zmian | backup + diff przed pierwszym apply (T11b) |
| R3 | Claude marketplace dryfuje (pierwszy `add` pobiera HEAD ≠ `25d785a`) | średnie | niezaakceptowany kod | verify + WARN + doctor; tag po S1 (T14) |
| R4 | Zmiana wpisu `extraKnownMarketplaces` bez zmiany źródła w `add` (lub odwrotnie) | średnie | `failureCode: declared`, brak instalacji | jedno źródło danych (T02/T04/T06), test zgodności źródeł |
| R5 | Codex: nowe pluginy pojawiają się u użytkownika Codex bez zgody | niskie | zaskoczenie | flaga `ai_codex`, opisane w PR i runbooku |
| R6 | Brak pakietów CLI Codex/Claude Code na Linux/Windows | pewne | CLI nie instalowane | instalacja CLI poza zakresem do weryfikacji nazw (T08); doctor raportuje; skrypty SKIP |
| R7 | Niepinowane `curl \| bash` (peon-ping, Homebrew) | stałe | reprodukowalność | tylko odnotowane; poza zakresem |
| R8 | `run_onchange_` z `lookPath` zmienia odcisk przy zmianie PATH | niskie | dodatkowe, idempotentne uruchomienie | test idempotencji (T13) |
| R15 | Błąd instalacji kończy skrypt exit 0, więc chezmoi uznaje go za wykonany i nie powtarza | pewne (zmierzone) | pluginy niezainstalowane bez widocznego błędu | plik statusu + `doctor --strict` + reset jednego klucza `entryState` (D-C1); test przebiegu w T06/T08/T09/T13 |
| R16 | Reset stanu zbyt szeroki (`delete-bucket`, `state reset`) uruchamia niezwiązane skrypty (sudo/pacman) | średnie | niezamierzone zmiany systemu | komenda drukowana przez doctor dotyczy jednego klucza; zakaz szerokich komend w docs; test, że ich nie zawiera (T09) |
| R9 | Zmiana formatu `claude plugin list --json` / `codex plugin list` | średnie | błędna detekcja „zainstalowane" | detekcja przez kod wyjścia + `jq` z fallbackiem; sprawdzenie w T06 krok 1 |
| R10 | Agent teams wyłączone na nowych hostach | niskie | brak teams | flaga; legacy zachowane |
| R11 | Ponowny `init` na istniejącym hoście cicho przestawia profil na `core` | wysokie bez D-G | zmiana pluginów bez zgody | D-G (`stat configFile`, jawny zapis legacy bez pytania), testy T03 |
| R12 | Zmiana tekstu promptu psuje flagi `--promptChoice/--promptBool` w skryptach/CI | średnie | błąd lub ignorowanie odpowiedzi | teksty jako stałe w `tests/ai/lib.sh`, test ich zgodności z `.chezmoi.toml.tmpl` (T03) |
| R13 | `chezmoi init` bez TTY i bez `--promptDefaults` kończy się błędem | pewne (zmierzone) | brak inicjalizacji w kontenerze/CI | dokumentacja `--promptDefaults` w runbooku; istniejące hosty nie dostają nowego pytania (D-G) |
| R14 | `minimal` ukrywa brak guarda worktree, jeśli ktoś oczekuje profilu „zero pluginów" | niskie | zdziwienie | `bare` zarezerwowany i odrzucany jawnie; opis w D-A |

## 10. Rekomendowany pierwszy PR implementacyjny

**PR-1** (T00, T01, T02, T03, T04, T04a, T11a). Powody: zero zmiany zachowania hostów istniejących (golden + testy `init` to dowodzą), jawny default `core` dla nowych inicjalizacji,
dane i logika wyboru profilu, od których zależą kolejne PR-y, oraz CI Linux od pierwszego dnia — wykrywa R1/R11/R12 zanim ruszą instalatory.

## 11. Decyzje i sprawy otwarte

Rozstrzygnięte przez użytkownika (2026-10-30):

- O1 → `minimal` = `git-workflows` + `development-lifecycle`; `bare` tylko zarezerwowany.
- O3 → tag `ai-workflow-v0.1.0-preview.1` na `25d785abee26ca7a3c87e8311f46e8a90f225301`, ale najpierw S1; utworzenie tagu wymaga osobnego polecenia.
- O4 → CI w PR-1, Linux obowiązkowy; Windows/macOS z instalatorami (PR-4).
- O5 → wszystkie GitHub Actions przypięte do pełnego 40-znakowego commit SHA z komentarzem wersji obok (np. `# v4`); aktualizacje pinów obsługuje Renovate; zakazane `@main`, `@master` i samo `@v4` (T04a).

Otwarte:

- O2: nazwy pakietów CLI (brew/pacman/AUR/winget/npm) dla Claude Code i Codex — weryfikacja w T08, nie zgadywać.
