# Micro Editor — Mappa del Codice Sorgente

Riferimenti verificati sul repository
[micro-editor/micro](https://github.com/micro-editor/micro).

---

## 1. ConfigDir — risoluzione XDG

**`internal/config/config.go:15-52`** — `InitConfigDir()`

```
Priorità:
  $MICRO_CONFIG_HOME           →  usa direttamente
  $XDG_CONFIG_HOME             →  $XDG_CONFIG_HOME/micro
  (nessuna)                    →  ~/.config/micro
  flag -config-dir <path>      →  <path>  (override)
```

La directory viene creata con `os.MkdirAll(ConfigDir, os.ModePerm)` (riga 46).

---

## 2. File di configurazione

### settings.json

| Operazione | Funzione | Riga |
|-----------|----------|------|
| Lettura | `ReadSettings()` | `settings.go:239-262` |
| Path | `filepath.Join(ConfigDir, "settings.json")` | 241 |
| Parsing | `json5.Unmarshal(input, &parsedSettings)` | 250 |
| Validazione | `validateParsedSettings()` | 255 |
| Scrittura | `WriteSettings()` | 353-391 |
| Formato output | `json.MarshalIndent(…, "", "    ")` | 386 |

Il formato è **JSON5** (commenti, trailing commas). Se il file manca, micro
usa i default interni senza errore.

### Default comuni (`settings.go:55-108`)

| Opzione | Default | Tipo |
|---------|---------|------|
| `autoindent` | `true` | bool |
| `backup` | `true` | bool |
| `cursorline` | `true` | bool |
| `diffgutter` | `false` | bool |
| `encoding` | `"utf-8"` | string |
| `eofnewline` | `true` | bool |
| `fileformat` | `"unix"` | string |
| `hlsearch` | `false` | bool |
| `hltrailingws` | `false` | bool |
| `ignorecase` | `true` | bool |
| `incsearch` | `true` | bool |
| `matchbrace` | `true` | bool |
| `mkparents` | `false` | bool |
| `rmtrailingws` | `false` | bool |
| `ruler` | `true` | bool |
| `savecursor` | `false` | bool |
| `saveundo` | `false` | bool |
| `scrollbar` | `false` | bool |
| `scrollmargin` | `3` | float64 |
| `softwrap` | `false` | bool |
| `splitbottom` | `true` | bool |
| `splitright` | `true` | bool |
| `syntax` | `true` | bool |
| `tabsize` | `4` | float64 |
| `tabstospaces` | `false` | bool |
| `truecolor` | `"auto"` | string |
| `wordwrap` | `false` | bool |

### Default globali (`settings.go:112-135`)

| Opzione | Default | Note |
|---------|---------|------|
| `autosave` | `0` | secondi; 0 = off |
| `clipboard` | `"external"` | `internal`, `external`, `terminal` |
| `colorscheme` | `"default"` | |
| `mouse` | `true` | |
| `pluginchannels` | `["https://…/channel.json"]` | riga 127 |
| `pluginrepos` | `[]` | repo aggiuntivi |
| `savehistory` | `true` | |
| `sucmd` | `"sudo"` | |

### Override filetype / glob

- **`ft:`** → `settings.go:338-350` — `UpdateFileTypeLocals()`
- **`glob:`** → `settings.go:321-333` — `UpdatePathGlobLocals()`

### bindings.json

Letto da `action.InitBindings()` — `cmd/micro/micro.go:406`.
Path: `ConfigDir/bindings.json`.

Le azioni plugin vanno referenziate con prefisso `lua:`, ad esempio
`"lua:comment.comment"` per il commento (vedi `bufpane.go:123-135`).

### init.lua

**`rtfiles.go:182-192`** — trattato come plugin con nome fisso `"initlua"`.
Non può essere rimosso con `plugin remove` (`plugin_installer.go:671-673`).

---

## 3. Sistema plugin

### Struttura su disco (`rtfiles.go:194-229`)

```
~/.config/micro/plug/
└── <nome>/
    ├── *.lua          sorgenti Lua
    ├── repo.json      metadati (Name, Description, Website)
    └── help/*.md      help opzionali
```

### Plugin built-in (`rtfiles.go:231-269`)

Embedded nel binario da `runtime/plugins/`. Possono essere sovrascritti
dall'utente (riga 235-239).

- `autoclose` — chiusura brackets
- `comment` — commenta/decommenta (`comment.lua:218`: `lua:comment.comment`)
- `diff` — git diffgutter
- `ftoptions` — override filetype
- `linter` — linting estensibile
- `literate` — syntax literate
- `status` — estensioni statusline

### Canale remoto (`plugin_installer.go:124-170`)

1. `PluginChannel` (JSON) contiene URL di repository
2. Ogni repository contiene array di `PluginPackage`
3. Formato repository: JSON5

**PluginPackage** (`plugin_installer.go:39-46`):
Name, Description, Author, Tags, Versions, Builtin.

**PluginVersion** (`plugin_installer.go:52-57`):
Version (semver), Url (zip), Require (dipendenze).

### Risoluzione dipendenze (`plugin_installer.go:515-542`)

Ricorsiva con backtracking:
1. Prende la prima dipendenza aperta
2. Se già selezionata e nel range → prosegue
3. Se fuori range → errore
4. Altrimenti prova dalla versione più recente

Messaggi di errore:
- riga 525/539: `unable to find a matching version for "<nome>"`
- riga 651: `Unknown plugin "<nome>"`

### Installazione (`plugin_installer.go:396-471`)

Scarica zip da `pv.Url`, estrae in `ConfigDir/plug/<nome>` (riga 412).

### Comandi (`plugin_installer.go:644-725`)

| Comando | Note |
|---------|------|
| `install` | risolve dipendenze, scarica |
| `remove` | elimina directory in plug/ |
| `update` | risolve versioni ≥ corrente |
| `list` | mostra plugin caricati |
| `search` | cerca per nome/descrizione/tag |
| `available` | elenca tutti i package |

---

## 4. Runtime files (`rtfiles.go:160-178`)

```go
add(RTColorscheme, "colorschemes", "*.micro")
add(RTSyntax,      "syntax",       "*.yaml")
add(RTSyntaxHeader,"syntax",       "*.hdr")
add(RTHelp,        "help",         "*.md")
```

Per ogni tipo cerca prima in `ConfigDir/<tipo>/`, poi negli asset embedded.
I file utente sovrascrivono quelli embedded con lo stesso nome.

---

## 5. Sequenza di boot (`cmd/micro/micro.go:293-484`)

```
 1. InitFlags()                       303
 2. InitLog()                         316
 3. config.InitConfigDir()            318   crea ConfigDir
 4. config.InitRuntimeFiles(true)     323   colorschemes, syntax, help
 5. config.InitPlugins()              324   scopre plugin su disco
 6. config.ReadSettings()             332   legge settings.json
 7. config.InitGlobalSettings()       336   merge default + user
 8. DoPluginFlags()                   358   -plugin/-clean → esegui ed esci
 9. screen.Init()                     360   inizializza terminale
10. config.LoadAllPlugins()           395   esegue codice Lua
11. action.InitBindings()             406   carica bindings.json
12. config.RunPluginFn("preinit")     411
13. LoadInput(args)                   419   apre file/buffer
14. config.RunPluginFn("init")        429
15. config.RunPluginFn("postinit")    434
16. config.InitColorscheme()          439
17. Event loop                        481
```

---

## 6. Comando -clean (`cmd/micro/clean.go:33-163`)

1. Riscrive `settings.json` rimuovendo opzioni al default (44-52)
2. Rileva opzioni orfane non più usate da plugin (55-69)
3. Pulisce file corrotti in `buffers/` (101-146)
4. Migra `plugins/` → `plug/` (148-160)
