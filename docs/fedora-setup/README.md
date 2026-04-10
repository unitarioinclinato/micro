# Micro Editor — Guida Setup Fedora

Kit di configurazione pronto all'uso per [micro](https://github.com/micro-editor/micro) su Fedora.
Ogni riferimento al codice sorgente è verificato direttamente sul repository upstream.

## Quickstart

```bash
cd docs/fedora-setup && chmod +x setup.sh && ./setup.sh
```

Lo script installa micro, le dipendenze clipboard, crea l'albero
`~/.config/micro/` e copia i file di configurazione inclusi.

## Contenuto della directory

| File | Descrizione |
|------|-------------|
| `setup.sh` | Script d'installazione automatica (DNF + XDG) |
| `settings.json` | Impostazioni consigliate (autosave, diffgutter, clipboard external, override per linguaggio) |
| `bindings.json` | Scorciatoie aggiuntive (Redo, Comment, DuplicateLine, DeleteLine, MoveLinesUp/Down) |
| `init.lua` | Template Lua utente con note su spellcheck via linter |
| `INTERNALS.md` | Mappa del codice sorgente con file e numeri di riga |

---

## 1. Installazione

### DNF (consigliato)

```bash
sudo dnf install -y micro
```

### Binario precompilato

```bash
curl https://getmic.ro | bash
sudo mv micro /usr/local/bin/
```

### Build da sorgente

```bash
sudo dnf install -y golang git make
git clone https://github.com/micro-editor/micro.git
cd micro
make build
sudo cp micro /usr/local/bin/
```

> **Nota:** non usare `go install` diretto — il Makefile inietta versione e
> commit hash nel binario; senza di essi il plugin manager non funziona
> (`Makefile:9`, `plugin_installer.go:366`).

### Clipboard

```bash
# Wayland (default su Fedora + GNOME):
sudo dnf install -y wl-clipboard

# X11:
sudo dnf install -y xclip
```

### Verifica

```bash
micro -version
```

---

## 2. Directory di configurazione

Micro segue lo standard XDG (`config.go:15-52`):

| Priorità | Sorgente | Path |
|:---------:|----------|------|
| 1 | `$MICRO_CONFIG_HOME` | il valore della variabile |
| 2 | `$XDG_CONFIG_HOME` | `$XDG_CONFIG_HOME/micro` |
| 3 | default | `~/.config/micro` |
| 4 | flag `-config-dir` | il path specificato (override assoluto) |

### Layout

```
~/.config/micro/
├── settings.json          impostazioni utente
├── bindings.json          keybinding personalizzati
├── init.lua               script Lua utente (plugin "initlua")
├── colorschemes/          temi *.micro
├── syntax/                definizioni *.yaml / *.hdr
├── plug/                  plugin installati
│   └── <nome>/
│       ├── *.lua
│       └── repo.json
├── backups/               salvataggi automatici
└── buffers/               stato cursori, undo, history
```

```bash
# Crea la struttura in una volta
mkdir -p ~/.config/micro/{colorschemes,syntax,plug,backups,buffers}
```

---

## 3. settings.json

**Path:** `~/.config/micro/settings.json` — letto con JSON5 (`settings.go:250`),
supporta commenti `//` e trailing commas. Basta specificare solo le opzioni
diverse dal default.

Copia la configurazione inclusa:

```bash
cp docs/fedora-setup/settings.json ~/.config/micro/settings.json
```

### Opzioni non-default abilitate

| Opzione | Valore | Default | Note |
|---------|--------|---------|------|
| `autosave` | `8` | `0` | salva ogni 8 secondi |
| `diffgutter` | `true` | `false` | mostra diff git nel margine |
| `hlsearch` | `true` | `false` | evidenzia risultati ricerca |
| `hltrailingws` | `true` | `false` | evidenzia spazi a fine riga |
| `mkparents` | `true` | `false` | crea directory padre al salvataggio |
| `rmtrailingws` | `true` | `false` | rimuove spazi trailing al salvataggio |
| `savecursor` | `true` | `false` | ricorda posizione cursore |
| `saveundo` | `true` | `false` | undo persistente tra sessioni |
| `scrollbar` | `true` | `false` | mostra scrollbar |
| `scrollmargin` | `5` | `3` | margine di scorrimento |
| `softwrap` | `true` | `false` | a-capo visuale righe lunghe |
| `tabstospaces` | `true` | `false` | spazi al posto dei tab |
| `wordwrap` | `true` | `false` | a-capo sulle parole |

### Override per linguaggio

```jsonc
"ft:go":       { "tabstospaces": false, "tabsize": 4 }
"ft:python":   { "tabstospaces": true,  "tabsize": 4 }
"ft:yaml":     { "tabstospaces": true,  "tabsize": 2 }
"ft:markdown": { "softwrap": true, "wordwrap": true, "tabsize": 2 }
"ft:ruby":     { "tabstospaces": true,  "tabsize": 2 }
"ft:json":     { "tabstospaces": true,  "tabsize": 2 }
"ft:shell":    { "tabstospaces": true,  "tabsize": 4 }
```

### Comandi runtime (dentro micro, `Ctrl-e`)

| Comando | Effetto |
|---------|---------|
| `set tabsize 2` | cambia globale, persiste in settings.json |
| `setlocal tabstospaces true` | solo buffer corrente, non persiste |
| `toggle softwrap` | toggle booleano |
| `show tabsize` | mostra valore corrente |
| `reset tabsize` | ripristina default |

---

## 4. bindings.json

Scorciatoie aggiuntive rispetto ai default:

| Tasto | Azione | Tipo |
|-------|--------|------|
| `Ctrl-r` | Redo | built-in |
| `Alt-/` | Commenta/decommenta | plugin (`lua:comment.comment`) |
| `Alt-d` | Duplica riga | built-in |
| `Ctrl-Shift-k` | Elimina riga | built-in |
| `Ctrl-Shift-Up` | Sposta righe su | built-in |
| `Ctrl-Shift-Down` | Sposta righe giù | built-in |

> **Importante:** l'azione di commento è fornita dal plugin `comment`
> (built-in, `runtime/plugins/comment/comment.lua:218-219`).
> In bindings.json va referenziata come `"lua:comment.comment"`, non come
> `"Comment"` — quest'ultimo non è un'azione built-in e genera l'errore
> *"action Comment does not exist"*.

---

## 5. Plugin

### Comandi

```bash
# Da terminale
micro -plugin list              # plugin installati
micro -plugin available         # plugin nel canale
micro -plugin search <parola>   # cerca
micro -plugin install <nome>    # installa
micro -plugin update            # aggiorna tutti
micro -plugin remove <nome>     # rimuovi

# Dall'interno di micro (Ctrl-e)
> plugin list
> plugin install <nome>
```

### Plugin built-in

| Plugin | Funzione | Disattivare in settings.json |
|--------|----------|------------------------------|
| `autoclose` | chiusura automatica `()[]{}""''` | `"autoclose": false` |
| `comment` | commenta / decommenta righe | `"comment": false` |
| `diff` | diff git nel gutter | `"diff": false` |
| `ftoptions` | override per filetype | `"ftoptions": false` |
| `linter` | linting automatico | `"linter": false` |
| `literate` | syntax literate programming | `"literate": false` |
| `status` | estensioni statusline | `"status": false` |

### Errori comuni

| Messaggio | Causa |
|-----------|-------|
| `Unknown plugin "<nome>"` | il plugin non esiste nel canale ufficiale |
| `unable to find a matching version` | le dipendenze richiedono una versione di micro non disponibile |

### Reset configurazione

```bash
micro -clean
```

Riscrive settings.json senza opzioni default, rimuove opzioni orfane,
pulisce buffer corrotti e migra la vecchia directory `plugins/` → `plug/`.

---

## 6. Spellcheck

Il repository micro **non** include un plugin nativo per aspell o hunspell.
L'unico riferimento è l'esempio `misspell` nell'help del plugin linter
(`runtime/plugins/linter/help/linter.md:80`).

### misspell (consigliato)

```bash
go install github.com/client9/misspell/cmd/misspell@latest
```

Attivazione in `init.lua`:

```lua
function init()
    linter.makeLinter("misspell", "", "misspell", {"%f"}, "%f:%l:%c: %m", {}, false, true)
end
```

### aspell via wrapper

```bash
sudo dnf install -y aspell aspell-it aspell-en

mkdir -p ~/bin
cat > ~/bin/aspell-lint << 'WRAPPER'
#!/usr/bin/env bash
file="$1"
line_num=0
while IFS= read -r line; do
    line_num=$((line_num + 1))
    for word in $(echo "$line" | aspell --lang=it list 2>/dev/null); do
        col=$(echo "$line" | grep -bo "$word" | head -1 | cut -d: -f1)
        col=$((col + 1))
        echo "${file}:${line_num}:${col}: parola sconosciuta: ${word}"
    done
done < "$file"
WRAPPER
chmod +x ~/bin/aspell-lint
```

In `init.lua`:

```lua
function init()
    linter.makeLinter("aspell", "markdown", "aspell-lint", {"%f"}, "%f:%l:%c: %m")
end
```

### textfilter interattivo

Seleziona il testo, poi:

```
Ctrl-e → textfilter aspell -a --lang=it
```

---

## 7. Cheatsheet

### Apertura file

```bash
micro file.txt                    # apri
micro file.txt +42                # vai a riga 42
micro -parsecursor file.txt:42:5  # riga 42, colonna 5
```

### Override da CLI

```bash
micro -syntax off file.c          # disabilita syntax per la sessione
micro -tabsize 2 file.py          # override tabsize
micro -options                    # elenca tutte le opzioni
```

### Help (dentro micro, `Ctrl-e`)

```
> help                  panoramica
> help options          tutte le opzioni
> help keybindings      tasti e azioni
> help commands         comandi disponibili
> help plugins          API Lua
> help linter           plugin linter
> help tutorial         tutorial passo-passo
```

---

## Riferimenti al codice

Per la mappa completa con numeri di riga, vedi **[INTERNALS.md](./INTERNALS.md)**.

| Area | File | Righe |
|------|------|-------|
| Risoluzione XDG | `internal/config/config.go` | 15–52 |
| Default settings | `internal/config/settings.go` | 55–135 |
| Lettura settings.json | `internal/config/settings.go` | 239–262 |
| Plugin discovery | `internal/config/rtfiles.go` | 160–230 |
| Plugin channel/install | `internal/config/plugin_installer.go` | 124–725 |
| Boot sequence | `cmd/micro/micro.go` | 293–484 |
| Comando -clean | `cmd/micro/clean.go` | 33–163 |
| Linter plugin | `runtime/plugins/linter/linter.lua` | intera |
| Comment plugin | `runtime/plugins/comment/comment.lua` | intera |

---

*Documentazione parte del fork
[unitarioinclinato/micro](https://github.com/unitarioinclinato/micro).
Progetto originale: [MIT License](../../LICENSE).*
