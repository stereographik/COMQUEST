/*
    CQ_fnc_hqStatusMarker  (server)
    [_hq] call CQ_fnc_hqStatusMarker;
    Status marker of a fully built HQ, seen by every player:
        [ROLLING THUNDER (root)][alive][1/7 objectives]     (rank: root, P1, P2... see CQ_fnc_objName)
    commander: alive / captured / killed; objectives = installations destroyed / total (depot,
    radio tower, fuel tanker, AA pits, HMG tower). Created when the HQ finishes building,
    updated by CQ_fnc_hqTick (text only rewritten when it changes); the dot and the AO circle
    appear only when the HQ is fully built (last objective ready); a fallen HQ loses its circle
    and keeps a black [NAME (rank)][destroyed] dot.
    Every objective gets its own marker as soon as it is set up during the construction (called
    every tick by CQ_fnc_hqTick, building included), orange [Depot][active], removed as soon as
    the objective is destroyed.
*/
params ["_hq"];
private _id = _hq get "id";

// one marker per objective, orange "[type][active]", from the moment it is set up until it is
// destroyed (then removed; CQ_objMarkDone keeps a destroyed one from coming back)
if (isNil "CQ_objMarkDone") then { CQ_objMarkDone = [] };
{
    private _o = _x;
    private _om = format ["cq_obj_%1_%2", _id, _forEachIndex];
    if (_om in CQ_objMarkDone) then { continue };
    if (!alive _o || { _o getVariable ["CQ_hacked", false] }) then {
        deleteMarker _om;
        CQ_objMarkDone pushBack _om;
        continue;
    };
    if (markerType _om == "") then {
        createMarker [_om, getPosATL _o];
        _om setMarkerType "mil_objective";
        _om setMarkerSize [0.7, 0.7];
        _om setMarkerColor "ColorOrange";
    };
    private _ot = format ["[%1][active]", _o getVariable ["CQ_objType", "Objective"]];
    if (markerText _om != _ot) then { _om setMarkerText _ot };
} forEach (_hq get "installations");

// the HQ's own marker (dot + AO circle) only once the last objective is ready
if !(_hq get "buildDone") exitWith {};
private _m = format ["cq_st_%1", _id];
// AO: a small dot carrying the text, inside a 1000 m red circle hatched in black (CQ_aoRadius)
// that disappears when the HQ falls
private _ma = format ["cq_ao_%1", _id];
private _mh = format ["cq_aoh_%1", _id];
if (markerType _m == "") then {
    createMarker [_m, _hq get "pos"];
    // CQ_hqMarkerType (a CfgMarkers class); a plain dot if that class does not exist
    _m setMarkerType ([CQ_hqMarkerType, "mil_dot"] select !(isClass (configFile >> "CfgMarkers" >> CQ_hqMarkerType)));
    _m setMarkerSize [0.8, 0.8];
    _m setMarkerColor "ColorOPFOR";
    createMarker [_mh, _hq get "pos"];
    _mh setMarkerShape "ELLIPSE";
    _mh setMarkerSize [CQ_aoRadius, CQ_aoRadius];
    _mh setMarkerBrush "FDiagonal";
    _mh setMarkerColor "ColorBlack";
    _mh setMarkerAlpha 0.5;
    createMarker [_ma, _hq get "pos"];
    _ma setMarkerShape "ELLIPSE";
    _ma setMarkerSize [CQ_aoRadius, CQ_aoRadius];
    _ma setMarkerBrush "Border";
    _ma setMarkerColor "ColorRed";
};
private _txt = if ((_hq get "state") == "Destroyed") then {
    if (markerShape _ma != "") then { deleteMarker _ma; deleteMarker _mh };
    _m setMarkerColor "ColorBlack";
    format ["[%1][destroyed]", [_id] call CQ_fnc_objName]
} else {
    private _cmd = switch (true) do {
        case (_hq getOrDefault ["cmdCaptured", false]): { "captured" };
        case (!alive (_hq get "commander")): { "killed" };
        default { "alive" };
    };
    private _all = _hq get "installations";
    // nGD: what the network does to it
    private _tags = "";
    if (_hq getOrDefault ["isolated", false]) then { _tags = _tags + "[isolated]" };
    if ((_hq getOrDefault ["stock", 0]) < CQ_lowStockShare * (_hq getOrDefault ["cap", 1])) then { _tags = _tags + "[low ammo]" };
    format ["[%1][%2][tower %5][%3/%4 objectives]%6", [_id] call CQ_fnc_objName, _cmd, { !alive _x || { _x getVariable ["CQ_hacked", false] } } count _all, count _all,
        ["down", "up"] select (alive (_hq get "radio")), _tags]
};
if (markerText _m != _txt) then { _m setMarkerText _txt };
