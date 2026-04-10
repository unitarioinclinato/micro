# 🖥️ Micro Editor — Setup Completo per Fedora

> Guida operativa con comandi pronti all'uso, derivata dall'analisi diretta del
> codice sorgente di [micro-editor/micro](https://github.com/micro-editor/micro).
> Ogni sezione contiene i riferimenti esatti ai file e righe sorgente.

---

## Quickstart (una riga)

```bash
cd docs/fedora-setup && chmod +x setup.sh && ./setup.sh
```

---

## 📂 Struttura file in questa directory

```
docs/fedora-setup/
├── README.md          ← questo file
├── INTERNALS.md       ← mappa tecnica dettagliata del codice sorgente
├── setup.sh           ← script di installazione e configurazione automatica
├── settings.json      ← configurazione micro "sana" per Fedora
├── bindings.json      ← keybinding extra consigliati
└── init.lua           ← script Lua utente con esempio spellcheck
```

---

## 1. Installazione su Fedora

### Opzione A — DNF (stabile)

```bash
sudo dnf install -y micro
```

### Opzione B — Binario precompilato (ultima versione)

```bash
curl https://getmic.ro | bash
sudo mv micro /usr/local/bin/
```

### Opzione C — Build da sorgente

```bash
# Requisiti: Go >= 1.19, git, make
sudo dnf install -y golang git make

git clone https://github.com/micro-editor/micro.git
cd micro
make build          # genera assets + compila
sudo cp micro /usr/local/bin/
```

> ⚠️ **Non usare `go install` diretto** — non inietta le variabili di versione nel
> binario, rompendo il plugin manager (`Makefile:9`, `plugin_installer.go:366`).

### Dipendenze clipboard

```bash
# Wayland (default Fedora con GNOME):
sudo dnf install -y wl-clipboard

# X11:
sudo dnf install -y xclip
```

### Verifica installazione

```bash
micro -version
# Output atteso:
#   Version: 2.x.x
#   Commit hash: xxxxxxx
#   Compiled on ...
```

---

## 2. Directory Layout

### Logica XDG (`internal/config/config.go:18-32`)

| Priorità | Variabile | Path risultante |
|----------|-----------|-----------------|
| 1 | `$MICRO_CONFIG_HOME` | `$MICRO_CONFIG_HOME` |
| 2 | `$XDG_CONFIG_HOME` | `$XDG_CONFIG_HOME/micro` |
| 3 | *(nessuna)* | `~/.config/micro` |
| 4 | `-config-dir <path>` | `<path>` (override CLI) |

### Creazione completa directory

```bash
# Crea tutto il layout in una volta
mkdir -p ~/.config/micro/{colorschemes,syntax,plug,backups,buffers}
```

### Layout risultante

```
~/.config/micro/                          ← config.go:33 (ConfigDir)
├── settings.json                         ← settings.go:241
├── bindings.json                         ← action/bindings.go
├── init.lua                              ← rtfiles.go:183 (plugin "initlua")
├── colorschemes/                         ← rtfiles.go:174 (*.micro)
├── syntax/                               ← rtfiles.go:175-176 (*.yaml, *.hdr)
├── plug/                                 ← rtfiles.go:195, plugin_installer.go:412
│   └── <plugin-name>/
│       ├── *.lua
│       └── repo.json
├── backups/                              ← opzione "backupdir"
└── buffers/                              ← savecursor / saveundo
    └── history                           ← savehistory
```

---

## 3. Configurazione `settings.json`

### Path esatto: `~/.config/micro/settings.json`

Il file viene letto con `json5.Unmarshal()` (`settings.go:250`), supporta:
- Commenti `//` e `/* */`
- Trailing commas
- Solo le opzioni **diverse dal default** vanno scritte

### Copia la configurazione "sana" inclusa

```bash
cp docs/fedora-setup/settings.json ~/.config/micro/settings.json
```

### Oppure crea manualmente

```bash
cat > ~/.config/micro/settings.json << 'EOF'
{
    "autoindent": true,
    "autosave": 8,
    "clipboard": "external",
    "colorscheme": "default",
    "cursorline": true,
    "diffgutter": true,
    "encoding": "utf-8",
    "hlsearch": true,
    "hltrailingws": true,
    "mkparents": true,
    "rmtrailingws": true,
    "savecursor": true,
    "saveundo": true,
    "scrollbar": true,
    "scrollmargin": 5,
    "softwrap": true,
    "tabsize": 4,
    "tabstospaces": true,
    "truecolor": "auto",
    "wordwrap": true,
    "ft:go": {
        "tabstospaces": false,
        "tabsize": 4
    },
    "ft:python": {
        "tabstospaces": true,
        "tabsize": 4
    },
    "ft:yaml": {
        "tabstospaces": true,
        "tabsize": 2
    },
    "ft:markdown": {
        "softwrap": true,
        "wordwrap": true,
        "tabsize": 2
    }
}
EOF
```

### Impostare opzioni a runtime (dentro micro)

```
Ctrl-e → set tabsize 2              # globale, persiste in settings.json
Ctrl-e → setlocal tabstospaces true # solo buffer corrente, non persiste
Ctrl-e → toggle softwrap            # toggle booleano
Ctrl-e → show tabsize               # mostra valore corrente
Ctrl-e → reset tabsize              # ripristina default
```

---

## 4. Gestione Plugin

### Canale ufficiale (`settings.go:127`)

```
https://raw.githubusercontent.com/micro-editor/plugin-channel/master/channel.json
```

Il canale è una lista di URL a repository, ogni repository contiene i metadati
e le versioni dei plugin in formato JSON5.

### Comandi CLI (`cmd/micro/micro.go:72-84`)

```bash
# Lista plugin installati
micro -plugin list

# Plugin disponibili nel canale
micro -plugin available

# Cerca un plugin
micro -plugin search <parola>

# Installa un plugin
micro -plugin install <nome>

# Aggiorna tutti i plugin installati
micro -plugin update

# Aggiorna un plugin specifico
micro -plugin update <nome>

# Rimuovi un plugin
micro -plugin remove <nome>
```

### Comandi dall'interno di micro (`Ctrl-e`)

```
> plugin list
> plugin available
> plugin search <parola>
> plugin install <nome>
> plugin update
> plugin update <nome>
> plugin remove <nome>
```

### Dove vengono installati (`plugin_installer.go:412`)

```
~/.config/micro/plug/<nome-plugin>/
├── *.lua          ← codice sorgente
├── repo.json      ← metadati (Name, Description, Website)
└── help/          ← file di aiuto opzionali
    └── *.md
```

### Plugin built-in (non rimovibili) — `runtime/plugins/`

| Plugin | Funzione | Disattivare |
|--------|----------|-------------|
| `autoclose` | Auto-chiusura brackets `()[]{}""''` | `"autoclose": false` |
| `comment` | Commenta/decommenta | `"comment": false` |
| `diff` | Git diff nel gutter | `"diff": false` |
| `ftoptions` | Override per filetype | `"ftoptions": false` |
| `linter` | Linting automatico | `"linter": false` |
| `literate` | Syntax Literate | `"literate": false` |
| `status` | Estensioni statusline | `"status": false` |

### Errori comuni

| Errore | Causa | Ref |
|--------|-------|-----|
| `Unknown plugin "<nome>"` | Plugin non esiste nel canale | `plugin_installer.go:651` |
| `unable to find a matching version for "<nome>"` | Dipendenze non risolvibili (es. richiede micro >= 3.x) | `plugin_installer.go:525,539` |
| `Error installing <nome>: ...` | Plugin esiste ma non è installabile sulla versione corrente | `plugin_installer.go:652-653` |

### Reset completo della configurazione

```bash
micro -clean
# Azioni (ref: cmd/micro/clean.go:33-163):
#   1. Riscrive settings.json senza opzioni default
#   2. Rimuove opzioni orfane (plugin non più installati)
#   3. Pulisce file corrotti in buffers/
#   4. Migra vecchia dir plugins/ → plug/
```

---

## 5. Spellcheck su Fedora

### ⚠️ Stato reale nel repository

**Il repo micro NON contiene un plugin nativo per aspell/hunspell.**

Cercando nell'intero codice:
```bash
grep -rn "spell\|aspell\|hunspell" --include="*.go" --include="*.lua" --include="*.md"
```
L'unico risultato è nell'help del linter (`runtime/plugins/linter/help/linter.md:74,80`):
```lua
-- Esempio dalla documentazione del linter
linter.makeLinter("misspell", "", "misspell", {"%f"}, "%f:%l:%c: %m", {}, false, true)
```

Questo usa **`misspell`** (un tool Go), non aspell/hunspell.

### Opzione 1: misspell (suggerito dalla doc ufficiale)

```bash
# Installa misspell (richiede Go)
go install github.com/client9/misspell/cmd/misspell@latest

# Aggiungi a init.lua per attivarlo su tutti i file
cat >> ~/.config/micro/init.lua << 'INITEOF'

function init()
    linter.makeLinter("misspell", "", "misspell", {"%f"}, "%f:%l:%c: %m", {}, false, true)
end
INITEOF
```

`misspell` trova errori ortografici comuni in inglese — non usa dizionari di sistema.

### Opzione 2: aspell via linter wrapper

```bash
# Installa aspell con dizionari
sudo dnf install -y aspell aspell-it aspell-en

# Crea wrapper che produce output nel formato file:line:col: message
mkdir -p ~/bin
cat > ~/bin/aspell-lint << 'WRAPPER'
#!/usr/bin/env bash
# Wrapper aspell per il linter di micro
# Output: file:line:col: messaggio
file="$1"
line_num=0
while IFS= read -r line; do
    line_num=$((line_num + 1))
    words=$(echo "$line" | aspell --lang=it list 2>/dev/null)
    for word in $words; do
        col=$(echo "$line" | grep -bo "$word" | head -1 | cut -d: -f1)
        col=$((col + 1))
        echo "${file}:${line_num}:${col}: parola sconosciuta: ${word}"
    done
done < "$file"
WRAPPER
chmod +x ~/bin/aspell-lint

# Aggiungi a init.lua
cat >> ~/.config/micro/init.lua << 'INITEOF'

function init()
    linter.makeLinter("aspell", "markdown", "aspell-lint", {"%f"}, "%f:%l:%c: %m")
end
INITEOF
```

### Opzione 3: textfilter interattivo

Dall'interno di micro, seleziona il testo e:
```
Ctrl-e → textfilter aspell -a --lang=it
```

---

## 6. Comandi Rapidi — Cheatsheet

### Gestione sessione

```bash
micro file.txt                   # Apri file
micro file.txt +42               # Apri a riga 42
micro -parsecursor file.txt:42:5 # Apri a riga 42, colonna 5
micro -debug file.txt            # Abilita debug logging
```

### Opzioni da CLI

```bash
micro -syntax off file.c        # Disabilita syntax per questa sessione
micro -tabsize 2 file.py        # Override tabsize per questa sessione
micro -options                   # Mostra tutte le opzioni disponibili
```

### Help dall'interno (`Ctrl-e`)

```
> help                    # Help generico
> help options            # Tutte le opzioni
> help keybindings        # Keybinding disponibili
> help commands           # Tutti i comandi
> help plugins            # API plugin Lua
> help linter             # Help plugin linter
> help tutorial           # Tutorial introduttivo
```

---

## 7. Riferimenti al Codice Sorgente

Vedi [INTERNALS.md](./INTERNALS.md) per la mappa completa con file e numeri di riga.

| Area | File sorgente | Righe chiave |
|------|---------------|-------------|
| XDG path resolution | `internal/config/config.go` | 15-52 |
| Settings default | `internal/config/settings.go` | 55-135 |
| Lettura settings.json | `internal/config/settings.go` | 239-262 |
| Plugin struct | `internal/config/plugin.go` | 68-75 |
| Plugin discovery | `internal/config/rtfiles.go` | 180-269 |
| Plugin channel fetch | `internal/config/plugin_installer.go` | 124-170 |
| Dependency resolver | `internal/config/plugin_installer.go` | 515-542 |
| Plugin CLI commands | `internal/config/plugin_installer.go` | 644-725 |
| Download & install | `internal/config/plugin_installer.go` | 396-471 |
| CLI flags | `cmd/micro/micro.go` | 33-46, 48-128 |
| Boot sequence | `cmd/micro/micro.go` | 293-484 |
| Clean command | `cmd/micro/clean.go` | 33-163 |
| Linter plugin | `runtime/plugins/linter/linter.lua` | 1-160 |
| Built-in plugins | `runtime/plugins/` | — |
| Help files | `runtime/help/` | — |

---

## Licenza

Questa documentazione è parte del fork [unitarioinclinato/micro](https://github.com/unitarioinclinato/micro).
Il progetto originale micro è distribuito sotto [MIT License](../../LICENSE).
