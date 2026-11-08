/*
    CQ_fnc_say  (server)
    [_key, _args, _hq] call CQ_fnc_say;
    Plays a story message from CQ_story to every player (CQ_fnc_storyClient), one line every
    CQ_storyLineGap seconds. _hq (optional HQ record): INTERCEPT lines are only heard while
    that HQ can talk on the radio (tower standing, or field radios before it is built).
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

private _radio = count _hq == 0 || { alive (_hq get "radio") } || { !(_hq getOrDefault ["buildDone", false]) };
private _lines = (selectRandom _variants) select { (_x select 0) != "INTERCEPT" || _radio };
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
