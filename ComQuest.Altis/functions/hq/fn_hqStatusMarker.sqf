/*
    CQ_fnc_hqStatusMarker  (server)
    [_hq] call CQ_fnc_hqStatusMarker;
    Status marker of a fully built HQ, seen by every player:
        [HQ#1][alive][1/7 objectives]
    commander: alive / captured / killed; objectives = installations destroyed / total (depot,
    radio tower, fuel tanker, AA pits, HMG tower). Created when the HQ finishes building,
    updated by CQ_fnc_hqTick (text only rewritten when it changes); a fallen HQ keeps a grey
    [HQ#1][destroyed] marker.
    Every objective also gets its own marker once the HQ is built, kept after the HQ falls:
        [Depot][active]   orange        [Depot][disabled]   yellow
*/
params ["_hq"];
if !(_hq get "buildDone") exitWith {};
private _id = _hq get "id";
private _m = format ["cq_st_%1", _id];
if (markerType _m == "") then {
    createMarker [_m, _hq get "pos"];
    _m setMarkerType "o_hq";
    _m setMarkerColor "ColorOPFOR";
};
private _txt = if ((_hq get "state") == "Destroyed") then {
    _m setMarkerColor "ColorGrey";
    format ["[HQ#%1][destroyed]", _id]
} else {
    private _cmd = switch (true) do {
        case (_hq getOrDefault ["cmdCaptured", false]): { "captured" };
        case (!alive (_hq get "commander")): { "killed" };
        default { "alive" };
    };
    private _all = _hq get "installations";
    format ["[HQ#%1][%2][%3/%4 objectives]", _id, _cmd, { !alive _x } count _all, count _all]
};
if (markerText _m != _txt) then { _m setMarkerText _txt };

// one marker per objective: [type][active] orange / [type][disabled] yellow
{
    private _o = _x;
    private _om = format ["cq_obj_%1_%2", _id, _forEachIndex];
    if (markerType _om == "") then {
        createMarker [_om, getPosATL _o];
        _om setMarkerType "mil_objective";
        _om setMarkerSize [0.7, 0.7];
    };
    private _on = alive _o;
    private _ot = format ["[%1][%2]", _o getVariable ["CQ_objType", "Objective"], ["disabled", "active"] select _on];
    if (markerText _om != _ot) then {
        _om setMarkerText _ot;
        _om setMarkerColor (["ColorYellow", "ColorOrange"] select _on);
    };
} forEach (_hq get "installations");
