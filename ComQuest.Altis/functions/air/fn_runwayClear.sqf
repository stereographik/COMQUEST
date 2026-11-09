/*
    CQ_fnc_runwayClear  (server)
    [_terrainToo] call CQ_fnc_runwayClear;
    Keeps the main runway free for the drones: everything on the runway and CQ_runwayMargin m
    around it, over its whole length (CQ_runwayBehind m behind the take-off spot to
    CQ_runwayLength ahead; CQ_runwayHalfWidth + margin either side of the centre line):
      - mission objects (bunkers, sandbags, statics, crates, wrecks...) are deleted
      - terrain objects are hidden (_terrainToo: once, at start)
    Spared: vehicles and people, MAGPIE's pads, and the repair stations (CQ_repairPoints).
*/
params [["_terrainToo", false]];
if (!isServer || { isNil "CQ_magRunway" }) exitWith {};
CQ_magRunway params ["_rp0", "_hdg0"];
private _half = CQ_runwayHalfWidth + CQ_runwayMargin;
private _inStrip = {
    params ["_p"];
    private _rel = _p vectorDiff _rp0;
    private _along = (_rel select 0) * sin _hdg0 + (_rel select 1) * cos _hdg0;
    private _side = (_rel select 0) * cos _hdg0 - (_rel select 1) * sin _hdg0;
    _along > -CQ_runwayBehind && { _along < CQ_runwayLength } && { abs _side < _half }
};
private _spared = {
    params ["_p"];
    ((missionNamespace getVariable ["CQ_repairPoints", []]) findIf { _x distance2D _p < CQ_repairRadius + 15 }) > -1
};
private _mid = _rp0 getPos [(CQ_runwayLength - CQ_runwayBehind) / 2, _hdg0];
private _rad = (CQ_runwayLength + CQ_runwayBehind) / 2 + _half + 50;
private _hidden = 0;
private _gone = [];
if (_terrainToo) then {
    private _roads = _mid nearRoads _rad;
    {
        private _p = getPosATL _x;
        if (!(_x in _roads) && { [_p] call _inStrip } && { !([_p] call _spared) }) then { hideObjectGlobal _x; _hidden = _hidden + 1 };
    } forEach (nearestTerrainObjects [_mid, [], _rad, false, true]);
};
{
    private _o = _x;
    if (_o isKindOf "CAManBase" || { _o isKindOf "Logic" } || { _o isKindOf "HeliH" }
        || { (_o isKindOf "LandVehicle" || { _o isKindOf "Air" } || { _o isKindOf "Ship" }) && { !(_o isKindOf "StaticWeapon") } && { alive _o } }) then { continue };
    private _p = getPosATL _o;
    if !([_p] call _inStrip) then { continue };
    if ([_p] call _spared) then { continue };
    _gone pushBack typeOf _o;
    { deleteVehicle _x } forEach (crew _o);
    deleteVehicle _o;
} forEach (nearestObjects [_mid, ["All"], _rad]);
if (_hidden > 0 || { _gone isNotEqualTo [] }) then {
    ["Runway cleared: %1 terrain objects hidden, %2 mission objects removed %3", [_hidden, count _gone, _gone arrayIntersect _gone]] call CQ_fnc_log;
};
