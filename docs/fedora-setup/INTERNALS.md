# Micro Editor — Mappa Tecnica del Codice Sorgente

> Documento di riferimento interno. Ogni affermazione è collegata al file e riga
> del repository `micro-editor/micro`.

---

## 1. Risoluzione ConfigDir (XDG)

**File:** `internal/config/config.go:15-52`

```
Priorità (identica allo standard XDG):
┌─────────────────────────┬──────────────────────────────────┐
│ Variabile               │ Path risultante                  │
├─────────────────────────┼──────────────────────────────────┤
│ $MICRO_CONFIG_HOME      │ $MICRO_CONFIG_HOME               │
│ $XDG_CONFIG_HOME (set)  │ $XDG_CONFIG_HOME/micro           │
│ (nessuna)               │ ~/.config/micro                  │
│ -config-dir <path>      │ <path> (override, riga 35-41)    │
└─────────────────────────┴──────────────────────────────────┘
```

La directory viene creata con `os.MkdirAll(ConfigDir, os.ModePerm)` — riga 46.

---

## 2. File di Configurazione

### 2.1 settings.json

**Lettura:** `internal/config/settings.go:239-262` (`ReadSettings()`)
- Path: `filepath.Join(ConfigDir, "settings.json")` — riga 241
- Formato: **JSON5** (supporta commenti e trailing commas) — libreria `github.com/micro-editor/json5`
- Parsing: `json5.Unmarshal(input, &parsedSettings)` — riga 250
- Validazione: `validateParsedSettings()` — riga 255
- Fallback: se il file non esiste, micro usa i default interni senza errore

**Scrittura:** `WriteSettings()` — righe 353-391
- Solo le opzioni **non-default** vengono scritte
- Formato output: `json.MarshalIndent(parsedSettings, "", "    ")` — riga 386
- Safe-write via `util.SafeWrite()` — riga 165

### 2.2 Default Comuni (buffer-local + global)

**File:** `internal/config/settings.go:55-108`

| Opzione | Default | Tipo |
|---------|---------|------|
| `autoindent` | `true` | bool |
| `backup` | `true` | bool |
| `cursorline` | `true` | bool |
| `diffgutter` | `false` | bool |
| `encoding` | `"utf-8"` | string |
| `fileformat` | `"unix"` (Linux) | string |
| `hlsearch` | `false` | bool |
| `ignorecase` | `true` | bool |
| `matchbrace` | `true` | bool |
| `ruler` | `true` | bool |
| `savecursor` | `false` | bool |
| `saveundo` | `false` | bool |
| `scrollmargin` | `3` | float64 |
| `scrollspeed` | `2` | float64 |
| `softwrap` | `false` | bool |
| `syntax` | `true` | bool |
| `tabsize` | `4` | float64 |
| `tabstospaces` | `false` | bool |

### 2.3 Default Global-Only

**File:** `internal/config/settings.go:112-135`

| Opzione | Default | Note |
|---------|---------|------|
| `autosave` | `0` | secondi, 0=off |
| `clipboard` | `"external"` | valori: internal, external, terminal |
| `colorscheme` | `"default"` | — |
| `mouse` | `true` | — |
| `pluginchannels` | `["https://raw.githubusercontent.com/micro-editor/plugin-channel/master/channel.json"]` | riga 127 |
| `pluginrepos` | `[]` | repo aggiuntivi |
| `savehistory` | `true` | — |
| `sucmd` | `"sudo"` | — |

### 2.4 Override per filetype / glob

**Filetype** (`ft:`): `settings.go:338-350` — `UpdateFileTypeLocals()`
**Glob** (`glob:` o senza prefisso): `settings.go:321-333` — `UpdatePathGlobLocals()`

Esempio in settings.json:
```json
{
    "ft:go": { "tabstospaces": false },
    "glob:*.yml": { "tabsize": 2 }
}
```

### 2.5 bindings.json

Letto da `action.InitBindings()` — chiamato in `cmd/micro/micro.go:406`
Path: `ConfigDir/bindings.json`

### 2.6 init.lua

**File:** `internal/config/rtfiles.go:182-192`

```go
initlua := filepath.Join(ConfigDir, "init.lua")
if _, err := os.Stat(initlua); !os.IsNotExist(err) {
    p := new(Plugin)
    p.Name = "initlua"
    // ...
}
```

Il file `init.lua` viene trattato come un plugin con nome fisso `"initlua"`.
Non può essere rimosso con `plugin remove` — ref `plugin_installer.go:671-673`.

---

## 3. Sistema Plugin

### 3.1 Struttura su disco

**Ricerca plugin utente:** `internal/config/rtfiles.go:194-229`

```
~/.config/micro/plug/
└── <plugin-name>/           ← d.Name() (riga 200)
    ├── *.lua                ← sorgenti Lua (riga 208)
    ├── repo.json            ← metadati PluginInfo (riga 210-219)
    └── help/                ← file help opzionali
        └── *.md
```

**Plugin built-in:** `internal/config/rtfiles.go:231-269`
- Embedded nel binario via `runtime/plugins/`
- Possono essere sovrascritti dall'utente (riga 235-239)

**Plugin built-in disponibili:** (`runtime/plugins/`)
- `autoclose` — auto-chiusura brackets
- `comment` — commenta/decommenta
- `diff` — integrazione git diffgutter
- `ftoptions` — override filetype-specific
- `linter` — linting estensibile
- `literate` — syntax highlighting Literate
- `status` — estensioni statusline

### 3.2 repo.json (metadati plugin locale)

**File:** `internal/config/plugin_manager.go:26-46`

```go
type PluginInfo struct {
    Name string `json:"Name"`
    Desc string `json:"Description"`
    Site string `json:"Website"`
}
```

Formato: JSON standard (`encoding/json`).

### 3.3 Plugin Channel (catalogo remoto)

**Canale default:** `internal/config/settings.go:127`
```
https://raw.githubusercontent.com/micro-editor/plugin-channel/master/channel.json
```

**Flusso di risoluzione:** `internal/config/plugin_installer.go:124-170`
1. Il canale (`PluginChannel`) è un JSON che contiene URL di repository
2. Ogni `PluginRepository` contiene un array di `PluginPackage`
3. Formato repository: **JSON5** (riga 138, 158)

**Struttura PluginPackage:** `plugin_installer.go:39-46`
```go
type PluginPackage struct {
    Name        string
    Description string
    Author      string
    Tags        []string
    Versions    PluginVersions    // ogni versione ha Version, Url, Require
    Builtin     bool
}
```

**Struttura PluginVersion:** `plugin_installer.go:52-57`
```go
type PluginVersion struct {
    pack    *PluginPackage
    Version semver.Version       // semver: github.com/blang/semver
    Url     string               // URL dello zip da scaricare
    Require PluginDependencies   // dipendenze (incluso "micro" core)
}
```

### 3.4 Risoluzione Dipendenze

**Algoritmo:** `plugin_installer.go:515-542` — `Resolve()`

Risoluzione ricorsiva con backtracking:
1. Prende la prima dipendenza aperta
2. Se già selezionata e nel range → prosegue
3. Se già selezionata ma fuori range → **errore**
4. Altrimenti: ordina le versioni disponibili (dalla più recente), prova ciascuna

**Messaggi di errore esatti:**
- Riga 525: `unable to find a matching version for "<nome>"` — versione selezionata fuori range
- Riga 539: `unable to find a matching version for "<nome>"` — nessuna versione disponibile soddisfa il range
- Riga 651: `Unknown plugin "<nome>"` — plugin non trovato nel canale

### 3.5 Installazione Plugin

**Download:** `plugin_installer.go:396-471` — `DownloadAndInstall()`
- Scarica lo zip da `pv.Url`
- Estrae in `ConfigDir/plug/<nome>` (riga 412)
- Gestisce sia zip con directory root che senza (righe 421-434)

### 3.6 Comandi Plugin Manager

**File:** `plugin_installer.go:644-725` — `PluginCommand()`

| Comando | Azione | Note |
|---------|--------|------|
| `install` | Risolve dipendenze e scarica | Riga 646-665 |
| `remove` | Elimina `ConfigDir/plug/<dir>` | Riga 668-693 |
| `update` | Risolve versioni >= corrente | Riga 694-695, `UpdatePlugins()` 608-642 |
| `list` | Mostra plugin caricati | Riga 696-707 |
| `search` | Cerca per nome/descrizione/tag | Riga 708-715 |
| `available` | Lista tutti i package del canale | Riga 716-721 |

### 3.7 CLI flags

**File:** `cmd/micro/micro.go:39-40`
```go
flagPlugin = flag.String("plugin", "", "Plugin command")
flagClean  = flag.Bool("clean", false, "Clean configuration directory")
```

Esecuzione: `DoPluginFlags()` — micro.go:131-145
```go
config.PluginCommand(os.Stdout, *flagPlugin, args)
```

---

## 4. Runtime Files

**File:** `internal/config/rtfiles.go:161-178`

```go
func InitRuntimeFiles(user bool) {
    add(RTColorscheme, "colorschemes", "*.micro")   // riga 174
    add(RTSyntax, "syntax", "*.yaml")                // riga 175
    add(RTSyntaxHeader, "syntax", "*.hdr")           // riga 176
    add(RTHelp, "help", "*.md")                      // riga 177
}
```

Per ogni tipo, prima cerca in `ConfigDir/<tipo>/`, poi nel binario embedded.
I file utente **sovrascrivono** quelli embedded con lo stesso nome (riga 129-136).

---

## 5. Spellcheck — Stato nel Repository

**Risultato ricerca:** `grep -rn "spell\|aspell\|hunspell"` su tutto il repo:
- **Unica menzione:** `runtime/plugins/linter/help/linter.md:74,80`
- Tool suggerito: **`misspell`** (tool Go, non aspell/hunspell)
- È un **esempio** nell'help del linter, non un plugin dedicato

```lua
-- Dal linter.md:80
linter.makeLinter("misspell", "", "misspell", {"%f"}, "%f:%l:%c: %m", {}, false, true)
```

**NON esiste** nel repo:
- Plugin "aspell" nel canale ufficiale
- Integrazione nativa con aspell/hunspell
- Nessun comando `spell` o `spellcheck`

L'errore `unable to find a matching version for "aspell"` è prodotto da:
- `plugin_installer.go:651`: `Unknown plugin "aspell"` — se il plugin non è nel canale
- `plugin_installer.go:525/539`: se c'è ma le dipendenze non matchano

---

## 6. Build da Sorgente

**File:** `Makefile:24-31`

```bash
# Build completa (con generazione assets)
make build

# Build veloce (senza rigenerare assets)
make build-quick

# Build con debug
make build-dbg

# Installa in $GOPATH/bin
make install

# Test
make test    # → go test ./internal/... && go test ./cmd/...
```

**Variabili iniettate nel binario:**
- `Version` — dal tag git
- `CommitHash` — sha corto
- `CompileDate` — data compilazione

**IMPORTANTE** (README.md:179): `go get` diretto è sconsigliato perché non imposta
queste variabili, rompendo il plugin manager (che usa `util.Version` per risolvere
la dipendenza "micro" — ref `plugin_installer.go:366`).

---

## 7. Sequenza di Boot

**File:** `cmd/micro/micro.go:293-484` — `main()`

```
1. InitFlags()                          ← riga 303
2. InitLog()                            ← riga 316
3. config.InitConfigDir()               ← riga 318 (crea ConfigDir)
4. config.InitRuntimeFiles(true)        ← riga 323 (carica colorschemes, syntax, help)
5. config.InitPlugins()                 ← riga 324 (scopre plugin su disco)
6. config.ReadSettings()                ← riga 332 (legge settings.json)
7. config.InitGlobalSettings()          ← riga 336 (merge default + user settings)
8. DoPluginFlags()                      ← riga 358 (se -plugin/-clean → esegui e esci)
9. screen.Init()                        ← riga 360 (inizializza terminale)
10. config.LoadAllPlugins()              ← riga 395 (esegue codice Lua plugin)
11. action.InitBindings()                ← riga 406 (carica bindings.json)
12. config.RunPluginFn("preinit")        ← riga 411
13. LoadInput(args)                      ← riga 419 (apre file/buffer)
14. config.RunPluginFn("init")           ← riga 429
15. config.RunPluginFn("postinit")       ← riga 434
16. config.InitColorscheme()             ← riga 439
17. Event loop                           ← riga 481-483
```

---

## 8. Comando -clean

**File:** `cmd/micro/clean.go:33-163`

Azioni:
1. Riscrive `settings.json` rimuovendo opzioni default (riga 44-52)
2. Rileva opzioni orfane (non più usate da plugin) (riga 55-69)
3. Pulisce file corrotti in `buffers/` (riga 101-146)
4. Migra vecchia directory `plugins/` → `plug/` (riga 148-160)
