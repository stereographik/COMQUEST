/*
    CQ_fnc_crateTick  (server, director task, every 30 s)
    Keeps CQ_crateCount full supply crates on the camp's crate row (CQ_crateSpots): a spot
    with no crate on it gets a fresh one (one per pass). Crates left empty far from the camp
    are cleaned up after CQ_crateCleanup s.
*/
if (time < CQ_crateNext) exitWith {};
CQ_crateNext = time + 30;
{
    private _p = _x;
    if (((nearestObjects [_p, [CQ_crateClass], 2.5]) findIf { alive _x }) == -1) exitWith {
        private _c = createVehicle [CQ_crateClass, _p, [], 0, "CAN_COLLIDE"];
        _c setDir CQ_baseDir;
        [_c] call CQ_fnc_crateFill;
        ["Supply crate restocked at the base"] call CQ_fnc_log;
    };
} forEach CQ_crateSpots;
{
    private _c = _x;
    if (_c distance2D CQ_basePos > 300) then {
        private _empty = (count (getMagazineCargo _c select 0) + count (getItemCargo _c select 0)) == 0;
        if (_empty) then {
            if ((_c getVariable ["CQ_emptyT", -1]) < 0) then { _c setVariable ["CQ_emptyT", time] };
            if (time - (_c getVariable ["CQ_emptyT", time]) > CQ_crateCleanup) then { deleteVehicle _c };
        };
    };
} forEach ((allMissionObjects CQ_crateClass) select { _x getVariable ["CQ_crate", false] });
