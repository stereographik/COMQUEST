/*
    CQ_fnc_cmdCapture  (server, from the hold action through remoteExec)
    ["capture", _commander, _player] call CQ_fnc_cmdCapture;
    The enemy HQ commander surrenders: disarmed, captive, follows the capturing player's squad.
    His HQ counts its commander as gone (it can no longer expand), and his intel goes on the
    map: every HQ of his network (chain of HQs within CQ_commsRange of each other, starting
    from his own) gets an exact position marker for all players.
*/
params ["_mode", "_cmd", "_p"];
if (!isServer || { !alive _cmd } || { _cmd getVariable ["CQ_captured", false] }) exitWith {};
private _hq = CQ_hqs getOrDefault [_cmd getVariable ["CQ_hqId", -1], createHashMap];
if (count _hq == 0) exitWith {};

_cmd setVariable ["CQ_captured", true, true];
_hq set ["cmdCaptured", true];
removeAllWeapons _cmd;
_cmd setCaptive true;
_cmd enableAI "PATH";
[_cmd] joinSilent (group _p);
_cmd allowFleeing 0;
[_p, 80, "HQ commander captured"] call CQ_fnc_scoreAdd;

// his network: BFS over active HQs within comms range
private _act = (values CQ_hqs) select { (_x get "state") in CQ_activeStates };
private _seen = [_hq];
private _q = [_hq];
while { _q isNotEqualTo [] } do {
    private _cur = _q deleteAt 0;
    {
        if (!(_x in _seen) && { ((_x get "pos") distance2D (_cur get "pos")) <= CQ_commsRange }) then { _seen pushBack _x; _q pushBack _x };
    } forEach _act;
};
{
    private _id = _x get "id";
    _x set ["revealed", true];
    private _m = createMarker [format ["cq_intel_%1_%2", _id, floor time], _x get "pos"];
    _m setMarkerType "o_hq";
    _m setMarkerColor "ColorOPFOR";
    _m setMarkerText format ["Objective %1 (intel)", [_id] call CQ_fnc_objName];
    (_x get "markers") pushBack _m;
} forEach _seen;
["Commander captured", format ["%1 captured the commander of HQ #%2: %3 HQ positions revealed", name _p, _hq get "id", count _seen]] call CQ_fnc_announce;
["cmdCaptured", [[_hq get "id"] call CQ_fnc_objName, count _seen]] call CQ_fnc_say;
