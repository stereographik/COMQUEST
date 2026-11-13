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
