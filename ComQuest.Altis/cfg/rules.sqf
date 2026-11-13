/*
    cfg\rules.sqf  (loaded on every machine by CQ_fnc_settings)
    The server rules: map briefing ("Server rules"), the tablet's RULES tab, and the first-join
    agreement (CQ_fnc_conduct). Server admins may edit them freely.
*/
CQ_rulesIntro = "ComQuest is a co-op mission. Play together, play fair. Admins can warn, mute, send to base or kick.";
CQ_rules = [
    "Respect everyone. No harassment, insults, slurs or discrimination (origin, gender, religion, sexuality, skill), in chat, on voice or in names. No mocking new players, no rage: disagree calmly or let it go.",
    "No teamkilling, intentional or reckless. Check your target and your backblast.",
    "No griefing in base: don't destroy, block or steal vehicles, crates or defences.",
    "Squad respawn vehicles belong to their squad: don't take or lock someone else's.",
    "Follow your squad leader. Squad leaders: lead, don't boss.",
    "Keep comms usable: no spam, no music or noise on the radio, no shouting over orders.",
    "Pilots fly for the team: don't crash aircraft for fun, don't land on players.",
    "No exploits, no cheats, no abuse of game bugs or of the debug tools.",
    "Respect admins' decisions; dispute them later, not mid-game.",
    "Have fun, and help new players learn."
];
CQ_reportReasons = ["Toxic behaviour", "Teamkilling", "Griefing", "Cheating or exploits", "Other"];

// Player names (CQ_fnc_nameCheck, checked when a player joins; very strict). A name that breaks a
// rule: the player is shown why and how to fix it, then his mission ends (the host only gets a
// warning). Admins are alerted, the log keeps it.
CQ_nameCheck = true;
CQ_nameMin = 3;                          // characters
CQ_nameMax = 20;
// allowed: A-Z a-z 0-9, space, - _ . (no accents, brackets, symbols, emoji)
CQ_nameMinLetters = 2;                   // at least this many letters
CQ_nameMaxRepeat = 3;                    // no character more than this many times in a row
// reserved: a name may not use these as a word or start with them (impersonation of staff or of
// the mission's voices); default profile names are refused as a word ("Player1")
CQ_nameReserved = ["admin", "moderator", "modo", "server", "serveur", "staff", "owner", "crossroad", "magpie", "comhat", "anthropic", "claude"];
CQ_nameDefaults = ["player", "joueur", "soldier", "unknown", "noname", "user", "newplayer"];
// forbidden words (insults, slurs, hate, sex), English and French. Checked after normalising the
// name: lower case, look-alike digits read as letters (0=o 1=i 3=e 4=a 5=s 7=t 8=b), everything
// that is not a letter removed, repeated letters collapsed ("F.u_u-c k" = "fuck").
// CQ_nameBadWords: refused anywhere in the name. CQ_nameBadWholeWords: refused only as a whole
// word (they hide inside ordinary words: grape, unique, computer, canal, Montenegro...).
// Admins: extend freely.
CQ_nameBadWords = [
    "fuck", "fvck", "fuk", "fcuk", "phuck", "shit", "bitch", "biatch", "cunt", "pussy", "asshole", "bastard", "whore", "slut",
    "nigger", "nigga", "faggot", "retard", "spastic", "tranny", "kike", "chink",
    "nazi", "hitler", "jihad", "rapist", "paedo", "porn", "penis", "vagina", "jizz", "suicide", "killyourself",
    "merde", "putain", "salope", "connard", "connasse", "encule", "batard", "niquer",
    "tapette", "bougnoul", "youpin", "couille", "chienne", "enfoire", "gouine", "trisomique"
];
CQ_nameBadWholeWords = [
    "dick", "cock", "fag", "negro", "paki", "heil", "sieg", "kkk", "isis", "rape", "pedo", "sex", "anal",
    "cum", "kys", "pute", "nique", "ntm", "fdp", "pd", "negre", "bite", "pedale", "mongol"
];
