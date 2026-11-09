/*
    CQ_fnc_say  (server)
    [_key, _args, _hq] call CQ_fnc_say;
    Plays a story message from CQ_story to every player (CQ_fnc_storyClient), one line every
    CQ_storyLineGap seconds.
    COMHAT (enemy radio) is only heard through a standing radio tower: the tower of _hq (optional
    HQ record) when one is given, else any enemy tower on the island.
    MAGPIE only speaks for her UAVs (keys starting with "mag"); her old scripted lines are dropped.
    Same key + same first argument at most every CQ_storyCooldown seconds.
*/
params [["_key", "", [""]], ["_args", [], [[]]], ["_hq", createHashMap, [createHashMap]]];
if (!isServer) exitWith {};

private _variants = CQ_story getOrDefault [_key, []];
if (_variants isEqualTo []) exitWith { ["Story: unknown key %1", [_key]] call CQ_fnc_log };

if (isNil "CQ_storyLast") then { CQ_storyLast = createHashMap };
private _ck = format ["%1|%2", _key, _args param [0, ""]];
if (time - (CQ_storyLast getOrDefault [_ck, -1e6]) < CQ_storyCooldown) exitWith {};
CQ_storyLast set [_ck, time];

private _radio = if (count _hq == 0) then {
    ((values CQ_hqs) findIf { alive (_x getOrDefault ["radio", objNull]) }) > -1
} else { alive (_hq getOrDefault ["radio", objNull]) };
private _isMag = (_key select [0, 3]) == "mag";
private _lines = (selectRandom _variants) select {
    ((_x select 0) != "COMHAT" || _radio) && { (_x select 0) != "MAGPIE" || _isMag }
};
if (_lines isEqualTo []) exitWith {};

[_lines, _args] spawn {
    params ["_lines", "_args"];
    {
        _x params ["_who", "_fmt"];
        private _txt = format ([_fmt] + _args);
        ["STORY | %1 | %2", [_who, _txt]] call CQ_fnc_log;
        [_who, _txt] remoteExec ["CQ_fnc_storyClient", 0];
        sleep CQ_storyLineGap;
    } forEach _lines;
};
