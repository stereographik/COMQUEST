/*
    CQ_fnc_clearWaypoints
    [_group] call CQ_fnc_clearWaypoints;   removes every waypoint of the group
*/
params ["_g"];
if (isNull _g) exitWith {};
for "_i" from (count waypoints _g - 1) to 0 step -1 do {
    deleteWaypoint [_g, _i];
};
