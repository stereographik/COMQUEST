/*
    CQ_fnc_say  (server)
    [_key, _args, _hq] call CQ_fnc_say;
    Plays a story message from CQ_story to every player (CQ_fnc_storyClient), one line every
    CQ_storyLineGap seconds.
    - Act variants: "key@<CQ_act>" is used when it exists, else "key". A variant is not
      repeated before all the others of that key were used (shuffle bag per key).
    - COMHAT (enemy radio) is only heard through a standing radio tower: the tower of _hq when
      given, else any enemy tower. If that tower falls while the message plays, the COMHAT line
      is cut mid-sentence and the rest is dropped.
    - MAGPIE only speaks for her UAVs (keys starting with "mag").
    - Rhythm (keys not in CQ_storyPriority): CROSSROAD lines at most every CQ_storyBudget s, and
      CROSSROAD / COMHAT stay silent CQ_storyQuietAfterFall s after an HQ falls.
    - Same key + same first argument at most every CQ_storyCooldown seconds.
*/
params [["_key", "", [""]], ["_args", [], [[]]], ["_hq", createHashMap, [createHashMap]]];
if (!isServer) exitWith {};

private _act = missionNamespace getVariable ["CQ_act", 1];
private _rk = format ["%1@%2", _key, _act];
if !(_rk in CQ_story) then { _rk = _key };
if !(_rk in CQ_story) exitWith { ["Story: unknown key %1", [_key]] call CQ_fnc_log };
private _variants = CQ_story get _rk;
if (_variants isEqualTo []) exitWith {};          // key kept silent on purpose

if (isNil "CQ_storyLast") then { CQ_storyLast = createHashMap };
private _ck = format ["%1|%2", _key, _args param [0, ""]];
if (time - (CQ_storyLast getOrDefault [_ck, -1e6]) < CQ_storyCooldown) exitWith {};

// shuffle bag: every variant once before any repeats
if (isNil "CQ_storyBag") then { CQ_storyBag = createHashMap };
private _bag = CQ_storyBag getOrDefault [_rk, []];
if (_bag isEqualTo []) then {
    for "_i" from 0 to count _variants - 1 do { _bag pushBack _i };
    _bag = _bag call BIS_fnc_arrayShuffle;
    CQ_storyBag set [_rk, _bag];
};
private _lines = +(_variants select ((_bag deleteAt 0) min (count _variants - 1)));

// who may speak
private _radioOf = {
    if (count _hq == 0) then { ((values CQ_hqs) findIf { alive (_x getOrDefault ["radio", objNull]) }) > -1 }
    else { alive (_hq getOrDefault ["radio", objNull]) }
};
private _isMag = (_key select [0, 3]) == "mag";
private _prio = _key in CQ_storyPriority;
private _quiet = !_prio && { time < (missionNamespace getVariable ["CQ_storyQuietUntil", -1]) };
private _budget = !_prio && { time - (missionNamespace getVariable ["CQ_storyCrossroadT", -1e6]) < CQ_storyBudget };
private _radio = call _radioOf;
_lines = _lines select {
    _x params ["_who"];
    switch (_who) do {
        case "MAGPIE": { _isMag };
        case "COMHAT": { _radio && { !_quiet } };
        case "CROSSROAD": { !_quiet && { !_budget } };
        default { true };
    }
};
if (_lines isEqualTo []) exitWith {};
CQ_storyLast set [_ck, time];
if ((_lines findIf { (_x select 0) == "CROSSROAD" }) > -1 && { !_prio }) then { CQ_storyCrossroadT = time };
if (_key in ["fallen", "fallenEarly"]) then { CQ_storyQuietUntil = time + CQ_storyQuietAfterFall };

[_lines, _args, _hq, _radioOf] spawn {
    params ["_lines", "_args", "_hq", "_radioOf"];
    {
        _x params ["_who", "_fmt"];
        private _txt = format ([_fmt] + _args);
        // the tower fell while we were talking: the enemy line is cut, the message ends
        if (_who == "COMHAT" && { !(call _radioOf) }) exitWith {
            private _cut = (_txt select [0, (floor (count _txt * 0.55)) max 8]) + "—";
            ["STORY | %1 | %2 (cut)", [_who, _cut]] call CQ_fnc_log;
            [_who, _cut] remoteExec ["CQ_fnc_storyClient", 0];
        };
        ["STORY | %1 | %2", [_who, _txt]] call CQ_fnc_log;
        [_who, _txt] remoteExec ["CQ_fnc_storyClient", 0];
        sleep CQ_storyLineGap;
    } forEach _lines;
};
