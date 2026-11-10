/*
    CQ_fnc_adrenalineSurge  (client, spawned by CQ_fnc_playerSetup for each life)
    Revive is the vanilla BI system (description.ext): a downed player waits up to
    CQ_bleedOut s for a medic, then respawns at the base.
    adrenalineSurge: a downed MEDIC may get back up on his own, at full health. A small roll
    every CQ_surgeEvery s while he is down, sized so the chance over the whole bleed-out is
    CQ_surgeChance (10 %): p = 1 - (1 - 0.10) ^ (CQ_surgeEvery / CQ_bleedOut). No enemy
    proximity rule: it can happen under fire.
*/
if (!hasInterface) exitWith {};
private _u = player;
private _n = CQ_bleedOut / CQ_surgeEvery;
private _p = 1 - ((1 - CQ_surgeChance) ^ (1 / _n));
while { alive _u && { _u == player } } do {
    waitUntil { sleep 1; !alive _u || { lifeState _u == "INCAPACITATED" } };
    if (!alive _u) exitWith {};
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
