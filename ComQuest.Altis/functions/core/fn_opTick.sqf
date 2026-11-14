/*
    CQ_fnc_opTick  (server, director task, every 10 s)
    OPERATION briefing, published to every player (CQ_opPub, shown by CQ_fnc_opClient in the
    map's "Operation" section). One section per objective type, and inside it one line per
    object, always in the same order, never removed:
      state 2  done      destroyed / neutralised (time + squad when known)
      state 1  active    standing, en route, hunting
      state 0  greyed    not available yet (team in reserve, nothing seen yet)
    Sections: Find where they land, Hostile HQs, then one per sub-objective type (AA pits, HMG
    towers, Radio towers, Supply depots, Fuel tankers: a line per object once it is built, under
    "Not found" until its HQ is complete), Supply convoys, Supply flights, Special forces,
    Carrier, Victory.
    CQ_opPub = [[done, title, summary, [[state, text], ...], icon], ...]
    A section whose lines are all greyed (nothing available yet) is hidden by the client.
*/
if (time < (missionNamespace getVariable ["CQ_opNext", 0])) exitWith {};
CQ_opNext = time + 10;
if (isNil "CQ_op") then { CQ_op = createHashMap };
if (isNil "CQ_opStartT") then { CQ_opStartT = time };
private _clock = {
    params ["_t"];
    private _s = round ((_t - CQ_opStartT) max 0);
    private _h = floor (_s / 3600); private _m = floor ((_s % 3600) / 60);
    format ["%1%2:%3%4", ["", "0"] select (_h < 10), _h, ["", "0"] select (_m < 10), _m]
};
private _squad = { params ["_u"]; if (!isNull _u && { isPlayer _u }) then { groupId group _u } else { "" } };
private _hqs = values CQ_hqs;
private _built = _hqs select { _x getOrDefault ["builtT", -1] > -1 };
_built = [_built, [], { _x get "id" }] call BIS_fnc_sortBy;       // always the same order

// ---- 1 first HQ located
private _loc = CQ_op getOrDefault ["located", []];
if (_loc isEqualTo []) then {
    private _act = _hqs select { (_x get "state") in CQ_activeStates };
    {
        private _h = _x;
        private _id = _h get "id";
        private _by = "";
        if (_id in (missionNamespace getVariable ["CQ_magHqSeen", createHashMap])) then { _by = "MAGPIE" };
        if (_by == "" && { _h getOrDefault ["revealed", false] }) then { _by = "intel" };
        if (_by == "") then {
            private _near = (allPlayers select { alive _x && { side group _x == west } && { _x distance2D (_h get "pos") < 300 } });
            if (_near isNotEqualTo []) then { _by = groupId group (_near select 0) };
        };
        if (_by != "") exitWith { _loc = [time, _by, _id]; CQ_op set ["located", _loc] };
    } forEach _act;
};

// ---- 2 HQ lines (destroyed: time + squad remembered once)
private _dead = 0;
private _sub = _built apply {
    private _h = _x;
    private _id = _h get "id";
    private _all = _h get "installations";
    private _cmd = switch (true) do {
        case (_h getOrDefault ["cmdCaptured", false]): { "captured" };
        case (!alive (_h get "commander")): { "killed" };
        default { "alive" };
    };
    if ((_h get "state") == "Destroyed") then {
        _dead = _dead + 1;
        if (_h getOrDefault ["opDone", []] isEqualTo []) then { _h set ["opDone", [time, [_h getOrDefault ["lastKiller", objNull]] call _squad]] };
        (_h get "opDone") params ["_t", "_sq"];
        [true, format ["%1  ·  destroyed %2  ·  commander %3%4", [_id] call CQ_fnc_objName, [_t] call _clock, _cmd, ["", "  ·  " + _sq] select (_sq != "")]]
    } else {
        [false, format ["%1  ·  commander %2  ·  %3/%4 objectives", [_id] call CQ_fnc_objName, _cmd, { !alive _x } count _all, count _all]]
    }
};

private _when = { params ["_t", "_sq"]; format ["%1%2", [_t] call _clock, ["", "  ·  " + _sq] select (_sq != "")] };

// ---- 3 sub-objectives: one section per type that can be disabled (destroyed or sabotaged),
//      one line per object as soon as it is built. Its HQ is "Not found" until the whole HQ is
//      built (then its name). Each object's type and death are cached per HQ ("opObj": index ->
//      [type, deadT, squad]) because a wreck may be deleted later.
private _objTypes = [
    ["AA", "AA pits", "\A3\ui_f\data\igui\cfg\simpleTasks\types\plane_ca.paa"],
    ["HMG tower", "HMG towers", "\A3\ui_f\data\igui\cfg\simpleTasks\types\rifle_ca.paa"],
    ["Radio tower", "Radio towers", "\A3\ui_f\data\igui\cfg\simpleTasks\types\radio_ca.paa"],
    ["Depot", "Supply depots", "\A3\ui_f\data\igui\cfg\simpleTasks\types\rearm_ca.paa"],
    ["Fuel tanker", "Fuel tankers", "\A3\ui_f\data\igui\cfg\simpleTasks\types\refuel_ca.paa"]
];
private _objRows = createHashMap;          // type -> rows
private _withObj = [_hqs select { (_x get "installations") isNotEqualTo [] }, [], { _x get "id" }] call BIS_fnc_sortBy;
{
    private _h = _x;
    private _name = if (_h getOrDefault ["buildDone", false]) then { [_h get "id"] call CQ_fnc_objName } else { "Not found" };
    private _cache = _h getOrDefault ["opObj", createHashMap];
    _h set ["opObj", _cache];
    private _n = createHashMap;            // type -> count so far in this HQ
    {
        private _o = _x;
        private _c = _cache getOrDefault [_forEachIndex, []];
        if (_c isEqualTo []) then {
            _c = [_o getVariable ["CQ_objType", ""], -1, ""];
            _cache set [_forEachIndex, _c];
            // the exact killer: the squad of the player who destroyed (or blew up) this object
            if (alive _o) then {
                _o setVariable ["CQ_opEntry", _c];
                _o addEventHandler ["Killed", {
                    params ["_o", "_k", "_i"];
                    private _c = _o getVariable ["CQ_opEntry", []];
                    if (_c isEqualTo [] || { (_c select 1) >= 0 }) exitWith {};
                    private _w = [_i, _k] select (isNull _i);
                    if (!isNull _w && { !(_w isKindOf "CAManBase") }) then { _w = effectiveCommander _w };
                    _c set [1, time];
                    _c set [2, if (!isNull _w && { isPlayer _w }) then { groupId group _w } else { "" }];
                    CQ_opNext = 0;      // refresh the briefing at once
                }];
            };
        };
        // fallback (died before the briefing first saw it): the HQ's last known attacker
        if ((_c select 1) < 0 && { !alive _o || { _o getVariable ["CQ_neutral", false] } }) then { _c set [1, time]; _c set [2, [_h getOrDefault ["lastKiller", objNull]] call _squad] };
        private _type = _c select 0;
        if (_type == "") then { continue };
        private _k = (_n getOrDefault [_type, 0]) + 1;
        _n set [_type, _k];
        private _total = { (_x getVariable ["CQ_objType", ""]) == _type } count (_h get "installations");
        private _label = if (_total > 1 || { _type == "AA" }) then { format ["%1  #%2", _name, _k] } else { _name };
        private _rows = _objRows getOrDefault [_type, []];
        _rows pushBack (if ((_c select 1) < 0) then { [1, format ["%1  ·  standing", _label]] }
            else { [2, format ["%1  ·  %2 %3", _label, switch (true) do { case (_type == "Radio tower"): { "down" }; case (alive _o && { _o getVariable ["CQ_neutral", false] }): { "neutralised" }; default { "destroyed" } }, [_c select 1, _c select 2] call _when]] });
        _objRows set [_type, _rows];
    } forEach (_h get "installations");
} forEach _withObj;
private _objSteps = _objTypes apply {
    _x params ["_type", "_title", "_icon"];
    private _rows = _objRows getOrDefault [_type, []];
    private _down = { (_x select 0) == 2 } count _rows;
    private _cnt = count _rows;
    if (_rows isEqualTo []) then { _rows = [[0, "none found yet"]] };
    [_cnt > 0 && { _down == _cnt }, _title, format ["%1 / %2 destroyed", _down, _cnt], _rows, _icon]
};

// ---- 4 / 5 supply convoys and flights: every one destroyed + the ones on their way now
private _supRows = {
    params ["_type", "_noun"];
    private _rows = (CQ_op getOrDefault [_type + "List", []]) apply { [2, format ["%1 destroyed %2", _noun, _x call _when]] };
    { _rows pushBack [1, format ["%1 en route", _noun]] } forEach (vehicles select { alive _x && { (_x getVariable ["CQ_supply", ""]) == _type } });
    if (_rows isEqualTo []) then { _rows = [[0, format ["no %1 seen yet", toLower _noun]]] };
    _rows
};
private _cvRows = ["convoy", "Convoy"] call _supRows;
private _flRows = ["flight", "Supply flight"] call _supRows;
private _cvDone = { (_x select 0) == 2 } count _cvRows;
private _flDone = { (_x select 0) == 2 } count _flRows;

// ---- 6 special forces: one line per team (neutralised / hunting / in reserve)
private _spList = CQ_op getOrDefault ["spectreList", []];
private _hunting = !isNull (missionNamespace getVariable ["CQ_huntGroup", grpNull]) && { ({ alive _x } count units CQ_huntGroup) > 0 };
private _spRows = [];
for "_i" from 0 to CQ_huntTeams - 1 do {
    _spRows pushBack (switch (true) do {
        case (_i < count _spList): { [2, format ["Spectre team %1 neutralised %2", _i + 1, (_spList select _i) call _when]] };
        case (_i == count _spList && { _hunting }): { [1, format ["Spectre team %1 hunting a squad", _i + 1]] };
        default { [0, format ["Spectre team %1 in reserve", _i + 1]] };
    });
};

// ---- side events: crash sites, hostages (CQ_fnc_opSide), the corridor outpost once spotted
private _sdRows = (CQ_op getOrDefault ["side", []]) apply {
    _x params ["", "_st", "_label", "_res", "_t", "_sq"];
    [_st, if (_st == 2) then { format ["%1  ·  %2  ·  %3", _label, _res, [_t, _sq] call _when] } else { format ["%1  ·  %2", _label, _res] }]
};
if (!isNil "CQ_outpostState" && { CQ_outpostState get "spotted" }) then {
    _sdRows pushBack ([[1, "Corridor outpost  ·  standing (jams MAGPIE, guards the supply flights)"], [2, "Corridor outpost  ·  taken"]] select (CQ_outpostState get "fallen"));
};
private _sdDone = { (_x select 0) == 2 } count _sdRows;
if (_sdRows isEqualTo []) then { _sdRows = [[0, "nothing yet"]] };

// ---- 7 carrier, 8 victory
private _pct = round (100 * ((missionNamespace getVariable ["CQ_carrierLeft", CQ_carrierHqs]) max 0) / (CQ_carrierHqs max 1));
private _won = !isNil "CQ_victory";
private _hqRows = _sub apply { [[1, 2] select (_x select 0), _x select 1] };
if (_hqRows isEqualTo []) then { _hqRows = [[0, "no HQ built yet"]] };

private _steps = [
    [_loc isNotEqualTo [], "Find where they land",
        if (_loc isEqualTo []) then { "Their beachhead will be due west of the carrier, within 2 km of the shore." }
        else { format ["%1  ·  %2  (%3)", [_loc select 0] call _clock, _loc select 1, [_loc select 2] call CQ_fnc_objName] }, [], "\A3\ui_f\data\igui\cfg\simpleTasks\types\search_ca.paa"],
    [_won, "Hostile HQs", format ["%1 / %2 destroyed", _dead, count _built], _hqRows, "\A3\ui_f\data\igui\cfg\simpleTasks\types\destroy_ca.paa"],
    [_cvDone > 0, "Supply convoys", format ["%1 destroyed", _cvDone], _cvRows, "\A3\ui_f\data\igui\cfg\simpleTasks\types\truck_ca.paa"],
    [_flDone > 0, "Supply flights", format ["%1 destroyed", _flDone], _flRows, "\A3\ui_f\data\igui\cfg\simpleTasks\types\heli_ca.paa"],
    [_sdRows findIf { (_x select 0) == 1 } == -1 && { _sdDone > 0 }, "Side events", format ["%1 done", _sdDone], _sdRows, "\A3\ui_f\data\igui\cfg\simpleTasks\types\help_ca.paa"],
    [(count _spList) >= CQ_huntTeams, "Special forces", format ["%1 / %2 teams neutralised", count _spList, CQ_huntTeams], _spRows, "\A3\ui_f\data\igui\cfg\simpleTasks\types\kill_ca.paa"],
    [_pct <= 0, "Carrier empty", format ["carrier at %1 %%", _pct], [], "\A3\ui_f\data\igui\cfg\simpleTasks\types\boat_ca.paa"],
    [_won, "Last HQ destroyed", ["VICTORY when the carrier is empty and no HQ stands", "VICTORY"] select _won, [], "\A3\ui_f\data\igui\cfg\simpleTasks\types\attack_ca.paa"]
];
_steps = (_steps select [0, 2]) + _objSteps + (_steps select [2, count _steps]);
if !(_steps isEqualTo (missionNamespace getVariable ["CQ_opPub", []])) then {
    CQ_opPub = _steps;
    publicVariable "CQ_opPub";
};
