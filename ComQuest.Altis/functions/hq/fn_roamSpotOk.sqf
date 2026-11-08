/*
    CQ_fnc_roamSpotOk
    [_pos] call CQ_fnc_roamSpotOk  ->  bool
    A spot ground vehicles can reach and sit on: dry land, gentle slope, not a hill top
    (more than CQ_roamHillRise above the ground 150 m around), no rocks within 30 m,
    away from the player base.
*/
params ["_p"];

if (surfaceIsWater _p) exitWith { false };
if (_p distance2D CQ_basePos < CQ_airPatrolBaseGap) exitWith { false };
if (((surfaceNormal _p) select 2) < CQ_roamMinNormal) exitWith { false };
private _h = getTerrainHeightASL _p;
private _around = 0;
for "_a" from 0 to 315 step 45 do { _around = _around + getTerrainHeightASL (_p getPos [150, _a]) };
if (_h - _around / 8 > CQ_roamHillRise) exitWith { false };
(nearestTerrainObjects [_p, ["ROCK", "ROCKS"], 30, false, true]) isEqualTo []
