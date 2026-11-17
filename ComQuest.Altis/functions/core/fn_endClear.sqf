/*
    CQ_fnc_endClear  (server)
    [] call CQ_fnc_endClear;   called by CQ_fnc_endgame once the DEBRIEF is published
    The game is over: the enemy stops and leaves the field, so players read the debrief in peace.
      - the director keeps only the tasks in CQ_endKeepTasks (no more HQs, carrier drops,
        sabotage, events, drone director)
      - every enemy is deleted: CSAT soldiers (alive or dead), their vehicles, aircraft, drones,
        static guns and mines, and every HQ's buildings (CQ_hqs "objects"), hostage civilians too
      - a sweep repeats every CQ_endClearEvery s until the restart: anything a running script
        (an insertion already in the air, a sabotage cycle...) still spawns is removed as well
    Friendlies keep everything: players, squads, MAGPIE, the base and its vehicles. A CSAT vehicle
    with a player inside is left alone (it was captured).
*/
if (!isServer) exitWith {};
CQ_gameOver = true; publicVariable "CQ_gameOver";

CQ_directorTasks = CQ_directorTasks select { (_x select 0) in CQ_endKeepTasks };

private _sweep = {
    private _n = 0;
    private _kill = { params ["_o"]; if (!isNull _o) then { deleteVehicle _o; _n = _n + 1 } };
    // HQ buildings, sandbags, guns, terminals
    {
        { [_x] call _kill } forEach (_y getOrDefault ["objects", []]);
    } forEach (missionNamespace getVariable ["CQ_hqs", createHashMap]);
    // CSAT vehicles, aircraft, drones, static guns (alive or wrecks), unless a player is inside
    {
        private _v = _x;
        if (getNumber (configOf _v >> "side") == 0 && { ((crew _v) findIf { isPlayer _x }) < 0 } && { isNil { _v getVariable "CQ_boughtBy" } }) then {
            { _v deleteVehicleCrew _x } forEach crew _v;
            [_v] call _kill;
        };
    } forEach (vehicles + (allDead select { !(_x isKindOf "CAManBase") }));
    // CSAT soldiers and the hostage civilians, alive or dead
    { if (!isPlayer _x && { side group _x in [east, civilian] || { getNumber (configOf _x >> "side") == 0 } }) then { [_x] call _kill } } forEach (allUnits + allDeadMen);
    // enemy mines (players' own charges and mines stay)
    private _own = []; { _own append (getAllOwnedMines _x) } forEach allPlayers;
    { if !(_x in _own) then { [_x] call _kill } } forEach allMines;
    { if (side _x in [east, civilian] && { units _x isEqualTo [] }) then { deleteGroup _x } } forEach allGroups;
    _n
};

private _n = [] call _sweep;
["ENDGAME: enemy removed (%1 object(s)), director keeps %2", [_n, (CQ_directorTasks apply { _x select 0 }) joinString ", "]] call CQ_fnc_log;

[_sweep] spawn {
    params ["_sweep"];
    while { true } do {
        sleep CQ_endClearEvery;
        private _n = [] call _sweep;
        if (_n > 0) then { ["ENDGAME: %1 late enemy object(s) removed", [_n]] call CQ_fnc_log };
    };
};
