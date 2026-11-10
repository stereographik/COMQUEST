/*
    CQ_fnc_adrenalineSurge  (client, spawned by CQ_fnc_playerSetup for each life)
    Revive is the vanilla BI system (description.ext): a downed player waits up to
    CQ_bleedOut s for a medic, then respawns at the base.
    adrenalineSurge: a downed MEDIC may get back up on his own, at full health. A small roll
    every CQ_surgeEvery s while he is down, sized so the chance over the whole bleed-out is
    CQ_surgeChance (10 %): p = 1 - (1 - 0.10) ^ (CQ_surgeEvery / CQ_bleedOut). No enemy
    proximity rule: it can happen under fire.
    BLEEDOUT: a downed player may give up and respawn at the base (key CQ_bleedKey, B) only
    while no conscious medic is within CQ_bleedMedicRange (500 m). The vanilla hold-to-respawn
    is off (ReviveForceRespawnDelay).
*/
if (!hasInterface) exitWith {};
private _u = player;
CQ_canBleed = false;
if (isNil "CQ_bleedKeyBound") then {
    CQ_bleedKeyBound = true;
    [] spawn {
        waitUntil { sleep 0.5; !isNull (findDisplay 46) };
        (findDisplay 46) displayAddEventHandler ["KeyDown", {
            params ["", "_k"];
            if (_k == CQ_bleedKey && { CQ_canBleed } && { lifeState player == "INCAPACITATED" }) then {
                CQ_canBleed = false;
                hintSilent "";
                player setDamage 1;
                true
            } else { false };
        }];
    };
};
// BLEEDOUT prompt while down: allowed only with no conscious medic within CQ_bleedMedicRange
[_u] spawn {
    params ["_u"];
    while { alive _u && { _u == player } } do {
        if (lifeState _u == "INCAPACITATED") then {
            private _medic = (allPlayers select { _x != _u && { alive _x } && { side group _x == west } && { lifeState _x != "INCAPACITATED" } && { _x getUnitTrait "Medic" } && { _x distance _u < CQ_bleedMedicRange } }) isNotEqualTo [];
            CQ_canBleed = !_medic;
            hintSilent parseText (if (_medic) then {
                format ["<t size='1.1' color='#918C3B'>A medic is within %1 m</t><br/>Hold on.", CQ_bleedMedicRange]
            } else {
                format ["<t size='1.1' color='#D45A4C'>No medic within %1 m</t><br/>Press <t color='#F2F1DF'>%2</t> to BLEEDOUT and respawn at the base.", CQ_bleedMedicRange, keyName CQ_bleedKey]
            });
        } else {
            if (CQ_canBleed) then { CQ_canBleed = false; hintSilent "" };
        };
        sleep 1;
    };
    hintSilent "";
};
private _n = CQ_bleedOut / CQ_surgeEvery;
private _p = 1 - ((1 - CQ_surgeChance) ^ (1 / _n));
while { alive _u && { _u == player } } do {
    waitUntil { sleep 1; !alive _u || { lifeState _u == "INCAPACITATED" } };
    if (!alive _u) exitWith {};
    _u setVariable ["CQ_downFed", true, true];
    [format ["%1 down  ·  %2", name _u, _u getVariable ["CQ_lastHit", "unknown"]]] remoteExec ["CQ_fnc_feed", 0];
    private _t0 = time;
    while { alive _u && { lifeState _u == "INCAPACITATED" } && { time - _t0 < CQ_bleedOut } } do {
        sleep CQ_surgeEvery;
        if (!alive _u || { lifeState _u != "INCAPACITATED" }) exitWith {};
        if (_u getUnitTrait "Medic" && { random 1 < _p }) exitWith {
            ["#rev", 1, _u] call BIS_fnc_reviveOnState;
            _u setVariable ["#rev", 1, true];
            _u setUnconscious false;
            _u setDamage 0;
            ["CQ_Phase", ["adrenalineSurge", "Back on your feet. Don't waste it."]] call BIS_fnc_showNotification;
            [format ["%1: adrenalineSurge after %2 s down", name _u, round (time - _t0)]] remoteExec ["CQ_fnc_log", 2];
        };
    };
    waitUntil { sleep 1; !alive _u || { lifeState _u != "INCAPACITATED" } };
};
