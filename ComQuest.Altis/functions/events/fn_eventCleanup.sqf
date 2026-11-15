/*
    CQ_fnc_eventCleanup  (server)
    [_label, _things] call CQ_fnc_eventCleanup;
    A side event is over (crash crate secured, hostage event ended, corridor outpost fallen):
    CQ_eventCleanup s later its props and the enemies it left behind are removed.
      _things  objects (props, statics, vehicles: their non-player crew goes with them), units and
               groups; already dead / deleted ones are skipped. A vehicle a player is in stays.
    Map buildings (terrain objects) are never touched.
*/
params ["_label", ["_things", []]];
if (!isServer) exitWith {};
["%1: over, props and enemies left removed in %2 s", [_label, CQ_eventCleanup]] call CQ_fnc_log;
[_label, _things] spawn {
    params ["_label", "_things"];
    sleep CQ_eventCleanup;
    private _n = 0;
    private _grps = [];
    {
        private _t = _x;
        if (_t isEqualType grpNull) then { _grps pushBackUnique _t; _t = units _t } else { _t = [_t] };
        {
            private _o = _x;
            if (isNull _o || { isPlayer _o }) then { continue };
            if (_o isKindOf "CAManBase") then {
                if (vehicle _o != _o && { (crew vehicle _o) findIf { isPlayer _x } > -1 }) then { continue };   // riding with a player
                _grps pushBackUnique group _o;
                deleteVehicle _o; _n = _n + 1;
            } else {
                if ((crew _o) findIf { isPlayer _x } > -1) then { continue };              // a player uses it
                if (isObjectHidden _o || { (getObjectType _o) == 1 }) then { continue };   // terrain object
                { if (!isPlayer _x) then { _grps pushBackUnique group _x; deleteVehicle _x } } forEach crew _o;
                deleteVehicle _o; _n = _n + 1;
            };
        } forEach _t;
    } forEach _things;
    { if (!isNull _x && { (units _x) isEqualTo [] }) then { deleteGroup _x } } forEach _grps;
    ["%1: cleaned up (%2 objects and units removed)", [_label, _n]] call CQ_fnc_log;
};
