local ADDON_NAME, ns = ...

-- =========================================================
-- TRANSLATIONS (fr / en)
-- =========================================================
local L = {
    fr = {
        ENABLED = "Proximité activée",
        DISABLED = "Proximité désactivée (volumes normaux rétablis)",
        NO_VOICE = "Chat vocal Blizzard indisponible sur ce client.",
        NOT_CONNECTED = "Pas connecté au vocal",
        NO_CHANNEL = "Aucun salon vocal actif",
        JOINING = "Connexion au salon vocal %s...",
        CHANNEL_GUILD = "Guilde",
        CHANNEL_PARTY = "Groupe",
        CHANNEL_INSTANCE = "Instance",
        CHANNEL_OTHER = "Salon",
        NOBODY = "Personne d'autre dans le salon",
        TOO_FAR = "trop loin",
        UNKNOWN = "?",
        YARDS = "%d m",
        RANGE_SET = "Portée : pleine voix jusqu'à %d m, muet au-delà de %d m.",
        HELP = {
            "/fv — afficher / masquer la fenêtre",
            "/fv on | off — activer / couper la proximité",
            "/fv join — rejoindre le vocal (guilde, sinon groupe)",
            "/fv range <max> [plein] — portée en mètres (ex. /fv range 40 8)",
            "/fv debug — état du vocal et des positions",
        },
        TT_TITLE = "ForeverVoice",
        TT_CLICK = "Clic : afficher / masquer la fenêtre",
    },
    en = {
        ENABLED = "Proximity enabled",
        DISABLED = "Proximity disabled (normal volumes restored)",
        NO_VOICE = "Blizzard voice chat is not available on this client.",
        NOT_CONNECTED = "Not connected to voice",
        NO_CHANNEL = "No active voice channel",
        JOINING = "Joining voice channel %s...",
        CHANNEL_GUILD = "Guild",
        CHANNEL_PARTY = "Group",
        CHANNEL_INSTANCE = "Instance",
        CHANNEL_OTHER = "Channel",
        NOBODY = "Nobody else in the channel",
        TOO_FAR = "too far",
        UNKNOWN = "?",
        YARDS = "%d yd",
        RANGE_SET = "Range: full voice up to %d yd, muted beyond %d yd.",
        HELP = {
            "/fv — show / hide the window",
            "/fv on | off — turn proximity on / off",
            "/fv join — join voice (guild, else group)",
            "/fv range <max> [full] — range in yards (e.g. /fv range 40 8)",
            "/fv debug — voice and position status",
        },
        TT_TITLE = "ForeverVoice",
        TT_CLICK = "Click: show / hide the window",
    },
}

ns.L = setmetatable({}, {
    __index = function(_, key)
        local lang = GetLocale() == "frFR" and "fr" or "en"
        return L[lang][key] or L.en[key] or key
    end,
})
