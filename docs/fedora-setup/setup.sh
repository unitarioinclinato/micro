#!/usr/bin/env bash
# ============================================================================
# setup.sh — Micro Editor: Setup completo per Fedora
# ============================================================================
# Uso:
#   chmod +x setup.sh && ./setup.sh
#
# Cosa fa:
#   1. Installa micro via dnf (o binario precompilato)
#   2. Installa dipendenze clipboard (wl-clipboard / xclip)
#   3. Crea tutta la struttura directory ~/.config/micro/
#   4. Copia settings.json, bindings.json, init.lua
#   5. Mostra stato plugin
#
# Riferimenti al codice sorgente:
#   - Logica XDG: internal/config/config.go:15-52
#   - Settings default: internal/config/settings.go:55-135
#   - Plugin directory: internal/config/rtfiles.go:195 ("plug")
#   - Plugin manager: internal/config/plugin_installer.go:644-725
#   - Clean command: cmd/micro/clean.go:33-163
# ============================================================================

set -euo pipefail

# Colori output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERR]${NC}   $*"; }

# ============================================================================
# 1. VARIABILI — Logica XDG identica a internal/config/config.go:18-32
# ============================================================================
# Priorità path (dal codice Go):
#   1. $MICRO_CONFIG_HOME
#   2. $XDG_CONFIG_HOME/micro
#   3. ~/.config/micro

if [[ -n "${MICRO_CONFIG_HOME:-}" ]]; then
    MICRO_DIR="$MICRO_CONFIG_HOME"
elif [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
    MICRO_DIR="${XDG_CONFIG_HOME}/micro"
else
    MICRO_DIR="${HOME}/.config/micro"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info "Config directory: ${MICRO_DIR}"
info "Script directory: ${SCRIPT_DIR}"

# ============================================================================
# 2. INSTALLAZIONE MICRO
# ============================================================================
install_micro() {
    info "Verifico se micro è già installato..."

    if command -v micro &>/dev/null; then
        ok "micro già installato: $(micro -version 2>/dev/null | head -1)"
        return 0
    fi

    info "Installo micro via dnf..."
    # Ref: README.md:127 — `dnf install micro` (Fedora)
    if command -v dnf &>/dev/null; then
        sudo dnf install -y micro
    else
        warn "dnf non trovato. Installo da binario precompilato..."
        # Ref: README.md:77-79
        curl https://getmic.ro | bash
        sudo mv micro /usr/local/bin/
    fi

    if command -v micro &>/dev/null; then
        ok "micro installato: $(micro -version 2>/dev/null | head -1)"
    else
        err "Installazione micro fallita"
        exit 1
    fi
}

# ============================================================================
# 3. DIPENDENZE CLIPBOARD
# ============================================================================
install_clipboard_deps() {
    info "Verifico dipendenze clipboard..."
    # Ref: README.md:153-159
    #   Per X11:      xclip o xsel
    #   Per Wayland:  wl-clipboard

    if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]]; then
        if ! command -v wl-copy &>/dev/null; then
            info "Installo wl-clipboard per Wayland..."
            sudo dnf install -y wl-clipboard
        fi
        ok "wl-clipboard disponibile"
    else
        if ! command -v xclip &>/dev/null && ! command -v xsel &>/dev/null; then
            info "Installo xclip per X11..."
            sudo dnf install -y xclip
        fi
        ok "xclip/xsel disponibile"
    fi
}

# ============================================================================
# 4. CREAZIONE STRUTTURA DIRECTORY
# ============================================================================
# Layout completo derivato dal codice sorgente:
#
# ~/.config/micro/                    ← ConfigDir (config.go:33)
# ├── settings.json                   ← settings.go:241
# ├── bindings.json                   ← action/bindings.go
# ├── init.lua                        ← rtfiles.go:183 (plugin "initlua")
# ├── colorschemes/                   ← rtfiles.go:174  (*.micro)
# ├── syntax/                         ← rtfiles.go:175-176 (*.yaml, *.hdr)
# ├── plug/                           ← rtfiles.go:195, plugin_installer.go:412
# │   └── <plugin-name>/
# │       ├── *.lua                   ← rtfiles.go:208
# │       └── repo.json               ← plugin_manager.go:26-30
# ├── backups/                        ← opzione "backupdir", default ConfigDir/backups
# └── buffers/                        ← savecursor/saveundo/savehistory
#     └── history                     ← savehistory

create_directory_structure() {
    info "Creo struttura directory..."

    # Directory principali
    # Ref: config.go:46 — os.MkdirAll(ConfigDir, os.ModePerm)
    mkdir -p "${MICRO_DIR}"

    # Ref: rtfiles.go:174 — AddRuntimeFilesFromDirectory(RTColorscheme, "colorschemes", "*.micro")
    mkdir -p "${MICRO_DIR}/colorschemes"

    # Ref: rtfiles.go:175-176
    mkdir -p "${MICRO_DIR}/syntax"

    # Ref: rtfiles.go:195 — plugdir := filepath.Join(ConfigDir, "plug")
    mkdir -p "${MICRO_DIR}/plug"

    # Ref: opzione backup, backupdir default = ConfigDir/backups
    mkdir -p "${MICRO_DIR}/backups"

    # Ref: savecursor, saveundo → buffers/
    mkdir -p "${MICRO_DIR}/buffers"

    ok "Directory create:"
    tree "${MICRO_DIR}" 2>/dev/null || find "${MICRO_DIR}" -type d | sort
}

# ============================================================================
# 5. COPIA FILE DI CONFIGURAZIONE
# ============================================================================
copy_config_files() {
    info "Copio file di configurazione..."

    # settings.json
    # Ref: settings.go:241 — filepath.Join(ConfigDir, "settings.json")
    if [[ -f "${MICRO_DIR}/settings.json" ]]; then
        warn "settings.json esiste già — backup in settings.json.bak"
        cp "${MICRO_DIR}/settings.json" "${MICRO_DIR}/settings.json.bak"
    fi
    cp "${SCRIPT_DIR}/settings.json" "${MICRO_DIR}/settings.json"
    ok "settings.json copiato"

    # bindings.json
    if [[ -f "${MICRO_DIR}/bindings.json" ]]; then
        warn "bindings.json esiste già — backup in bindings.json.bak"
        cp "${MICRO_DIR}/bindings.json" "${MICRO_DIR}/bindings.json.bak"
    fi
    cp "${SCRIPT_DIR}/bindings.json" "${MICRO_DIR}/bindings.json"
    ok "bindings.json copiato"

    # init.lua
    # Ref: rtfiles.go:183 — initlua := filepath.Join(ConfigDir, "init.lua")
    if [[ -f "${MICRO_DIR}/init.lua" ]]; then
        warn "init.lua esiste già — backup in init.lua.bak"
        cp "${MICRO_DIR}/init.lua" "${MICRO_DIR}/init.lua.bak"
    fi
    cp "${SCRIPT_DIR}/init.lua" "${MICRO_DIR}/init.lua"
    ok "init.lua copiato"
}

# ============================================================================
# 6. STATO FINALE
# ============================================================================
show_status() {
    echo ""
    echo "============================================================"
    echo "  MICRO EDITOR — Setup completato su Fedora"
    echo "============================================================"
    echo ""
    echo "  Config dir:  ${MICRO_DIR}"
    echo ""

    if command -v micro &>/dev/null; then
        echo "  Versione:    $(micro -version 2>/dev/null | head -1)"
    fi

    echo ""
    echo "  File installati:"
    echo "    ${MICRO_DIR}/settings.json"
    echo "    ${MICRO_DIR}/bindings.json"
    echo "    ${MICRO_DIR}/init.lua"
    echo ""
    echo "  Comandi utili (ref: cmd/micro/micro.go:72-84):"
    echo "    micro -version              # Mostra versione"
    echo "    micro -plugin list           # Lista plugin installati"
    echo "    micro -plugin available       # Plugin disponibili nel canale"
    echo "    micro -plugin install <nome>  # Installa un plugin"
    echo "    micro -plugin update          # Aggiorna tutti i plugin"
    echo "    micro -plugin remove <nome>   # Rimuovi un plugin"
    echo "    micro -plugin search <testo>  # Cerca plugin"
    echo "    micro -clean                 # Pulisci config (cmd/micro/clean.go)"
    echo "    micro -options               # Mostra tutte le opzioni"
    echo ""
    echo "  Dall'interno di micro (Ctrl-e):"
    echo "    > plugin list"
    echo "    > plugin install <nome>"
    echo "    > plugin update"
    echo "    > plugin remove <nome>"
    echo "    > set <opzione> <valore>"
    echo "    > help options"
    echo "    > help plugins"
    echo ""
    echo "============================================================"
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║  Micro Editor — Setup Fedora                           ║"
    echo "║  Basato sull'analisi del codice sorgente               ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""

    install_micro
    install_clipboard_deps
    create_directory_structure
    copy_config_files
    show_status
}

main "$@"
