/*
    CQ_fnc_airParkSpot  (server)
    [_center, _rMin, _rMax] call CQ_fnc_airParkSpot  ->  invisible helipad object
    Finds a flat spot clear of terrain blockers, objects and other helipads (CQ_lzClearance)
    on rings between _rMin and _rMax around _center, and places a landing pad there.
*/
params ["_center", ["_rMin", 90], ["_rMax", 260]];

private _spot = [];
for "_r" from _rMin to _rMax step 20 do {
    for "_a" from 0 to 330 step 30 do {
        private _p = _center getPos [_r, _a + random 15];
        if (surfaceIsWater _p) then { continue };
        if ((_p isFlatEmpty [-1, -1, 0.3, 10, 0, false, objNull]) isEqualTo []) then { continue };
        if !([_p, CQ_lzClearance] call CQ_fnc_isClear) then { continue };
        if ((nearestObjects [_p, ["HeliH"], 2 * CQ_lzClearance]) isNotEqualTo []) then { continue };
        _spot = _p;
        break;
    };
    if (_spot isNotEqualTo []) exitWith {};
};

if (_spot isEqualTo []) then {
    _spot = _center getPos [_rMin, random 360];
    ["No clear parking spot near %1, using %2", [mapGridPosition _center, mapGridPosition _spot]] call CQ_fnc_log;
};

createVehicle ["Land_HelipadEmpty_F", _spot, [], 0, "CAN_COLLIDE"]
