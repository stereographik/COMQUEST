/*
    CQ_fnc_hqStatusMarker  (server)
    [_hq] call CQ_fnc_hqStatusMarker;
    Status marker of a fully built HQ, seen by every player:
        [HQ#1][alive][1/7 objectives][TENSE]   (last: nervousness, CQ_fnc_hqNerves)
    commander: alive / captured / killed; objectives = installations destroyed / total (depot,
    radio tower, fuel tanker, AA pits, HMG tower). Created when the HQ finishes building,
    updated by CQ_fnc_hqTick (text only rewritten when it changes); a fallen HQ keeps a grey
    [HQ#1][destroyed] marker.
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
    format ["[HQ#%1][%2][%3/%4 objectives][%5]", _id, _cmd, { !alive _x } count _all, count _all, CQ_nervNames select (_hq getOrDefault ["nerv", 0])]
};
if (markerText _m != _txt) then { _m setMarkerText _txt };
