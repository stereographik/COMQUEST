/*
    CQ_fnc_empTick  (server, director task, every 2 s)
    The EMP event (settings: CQ_emp...):
      trigger   once per game, after CQ_empMinT s, on CSAT's first loss: an HQ's radio tower
                destroyed or its commander killed (captured does not count); never while a crash
                or a hostage event runs (it waits)
      armed     (CQ_fnc_empStart) countdown CQ_empTimer; the search circle shrinks to the exact
                spot once the device's guards or the device are seen (MAGPIE or players);
                warnings at 10, 5 and 1 min; time up -> CQ_fnc_empBlast "loss"
      defused   (CQ_fnc_empDefuse) the Stomper takes over (CQ_fnc_empStomper)
    Also publishes CQ_empEngAlive (an engineer player is alive: the slow defuse is hidden).
*/
if (!CQ_emp) exitWith {};
if (time < (missionNamespace getVariable ["CQ_empNext", 0])) exitWith {};
CQ_empNext = time + 2;

// engineer on the field? (the slow "anyone" defuse only shows when none is alive)
private _eng = (allPlayers findIf { alive _x && { _x getUnitTrait "engineer" } }) > -1;
if (missionNamespace getVariable ["CQ_empDbgNoEng", false]) then { _eng = false };   // debug: "No engineer" forces the slow defuse
if (_eng != (missionNamespace getVariable ["CQ_empEngAlive", true])) then { CQ_empEngAlive = _eng; publicVariable "CQ_empEngAlive" };

// ---- trigger: once per game
if (isNil "CQ_empState") exitWith {
    if (missionNamespace getVariable ["CQ_empDone", false]) exitWith {};
    if !(missionNamespace getVariable ["CQ_missionStarted", false]) exitWith {};
    if (time < CQ_empMinT) exitWith {};
    private _loss = (values CQ_hqs) findIf {
        private _r = _x getOrDefault ["radio", objNull];
        private _c = _x getOrDefault ["commander", objNull];
        (!isNull _r && { !alive _r }) || { !isNull _c && { !alive _c } && { !(_x getOrDefault ["cmdCaptured", false]) } }
    };
    if (_loss < 0) exitWith {};
    // another side event running: wait for it
    if (!isNil "CQ_crashState" && { !(CQ_crashState get "secured") }) exitWith {};
    if (!isNil "CQ_hstState" && { (CQ_hstState get "phase") != "done" }) exitWith {};
    ["EMP event: triggered (CSAT's first loss: HQ #%1)", [(values CQ_hqs) select _loss get "id"]] call CQ_fnc_log;
    if !([CQ_aiEventSize, "EMP"] call CQ_fnc_aiRoom) exitWith { CQ_empNext = time + 120 };   // no room: retry in 2 min
    if (call CQ_fnc_empStart) then { CQ_empDone = true } else { CQ_empNext = time + 120 };   // no site: retry in 2 min
};

private _s = CQ_empState;
// debug: state for the debug map (CQ_fnc_debugMap, layer "EMP") and a status line every 60 s
private _v = _s get "stomper";
private _goal = if (!(_s get "loaded")) then { _s get "pos" } else { _s get "target" };
CQ_empDbg = [CQ_empPhase, _s get "pos", _s get "found", (_s get "endT") - time, getMarkerPos "cq_emp",
    [[], getPosATL _v] select (!isNull _v), _goal, _s get "target", _s get "loaded", _s getOrDefault ["spawnPos", []],
    { alive _x && { _x isKindOf "CAManBase" } } count (_s get "men"), _s getOrDefault ["nudges", 0]];
publicVariable "CQ_empDbg";
if (time - (_s getOrDefault ["logT", -1e6]) > 60 && { CQ_empPhase in ["armed", "defused"] }) then {
    _s set ["logT", time];
    if (CQ_empPhase == "armed") then {
        ["EMP status: armed, %1 s left, found %2, %3 guards alive, engineer alive %4", [round ((_s get "endT") - time), _s get "found", CQ_empDbg select 10, CQ_empEngAlive]] call CQ_fnc_log;
    } else {
        ["EMP status: defused, Stomper %1 at %2, loaded %3, target %4, %5 m to its goal, %6 nudges, terminal %7",
            [["missing", "ok"] select !isNull _v, if (isNull _v) then { "-" } else { mapGridPosition _v }, _s get "loaded",
             if ((_s get "target") isEqualTo []) then { "none" } else { mapGridPosition (_s get "target") },
             if (isNull _v || { _goal isEqualTo [] }) then { -1 } else { round (_v distance2D _goal) }, _s getOrDefault ["nudges", 0],
             if (!isNull (_s get "holder") && { "B_UavTerminal" in (itemCargo (_s get "holder")) }) then { "on the table" } else { "taken" }]] call CQ_fnc_log;
    };
};
if (CQ_empPhase != "armed") exitWith {};
private _p = _s get "pos";
private _left = (_s get "endT") - time;
// HUD countdown under the signal panel (CQ_fnc_rdfClient): end time on the shared clock, sent again only when it moves
private _endS = ([time, serverTime] select isMultiplayer) + _left;
if (abs (_endS - (missionNamespace getVariable ["CQ_empHudEnd", -1])) > 1) then { CQ_empHudEnd = _endS; publicVariable "CQ_empHudEnd" };

// ---- found: a guard or the device seen by us (MAGPIE drones and players are on our side)
if !(_s get "found") then {
    private _seen = (west knowsAbout (_s get "device")) > 1.5
        || { ((_s get "men") findIf { alive _x && { (west knowsAbout _x) > 1.5 } && { _x distance2D _p < 150 } }) > -1 }
        || { (allPlayers findIf { alive _x && { _x distance2D _p < 60 } }) > -1 };
    if (_seen) then {
        _s set ["found", true];
        "cq_emp" setMarkerPos _p;
        "cq_emp" setMarkerSize [60, 60];
        "cq_emp_t" setMarkerPos _p;
        ["EMP event: device located at %1 (%2 s left)", [mapGridPosition _p, round _left]] call CQ_fnc_log;
        ["empFound", [mapGridPosition _p]] call CQ_fnc_say;
    };
};

// ---- countdown on the map, warnings
private _ss = floor ((_left max 0) mod 60);
"cq_emp_t" setMarkerText format [" EMP %1:%2%3", floor ((_left max 0) / 60), ["", "0"] select (_ss < 10), _ss];
{
    if (_left <= _x && { !(_x in (_s get "warned")) }) then {
        (_s get "warned") pushBack _x;
        if (_left > _x - 30) then { ["EMP device", format ["%1 min left before the EMP goes off (grid %2).", round (_x / 60), mapGridPosition (getMarkerPos "cq_emp")]] call CQ_fnc_announce };   // skipped warnings stay silent (timer cut)
    };
} forEach [600, 300, 60];
if (_left <= 0) then { ["loss", []] call CQ_fnc_empBlast };
