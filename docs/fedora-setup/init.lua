-- ~/.config/micro/init.lua
-- Plugin utente "initlua" — caricato automaticamente da micro
-- Ref: internal/config/rtfiles.go:182-192

local config = import("micro/config")
local shell  = import("micro/shell")
local micro  = import("micro")

function init()
    -- Integrazione spellcheck via linter API (se disponibile)
    -- Ref: runtime/plugins/linter/help/linter.md:42-81
    -- Usa 'misspell' (golang tool) come suggerito dalla doc ufficiale
    -- NOTA: aspell/hunspell NON hanno un plugin nativo nel repo micro.
    --       L'errore "unable to find a matching version for aspell" viene da
    --       plugin_installer.go:525,539 quando il plugin non esiste nel canale.
    --
    -- Per usare misspell: go install github.com/client9/misspell/cmd/misspell@latest
    -- Per usare aspell wrapper: vedi sotto

    -- Esempio: attiva misspell su tutti i filetype
    -- Richiede il plugin linter built-in attivo ("linter": true in settings.json)
    -- linter.makeLinter("misspell", "", "misspell", {"%f"}, "%f:%l:%c: %m", {}, false, true)
end
