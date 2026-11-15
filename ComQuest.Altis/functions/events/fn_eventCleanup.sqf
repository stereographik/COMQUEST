/*
    CQ_fnc_eventCleanup  (server)
    [_label, _things] call CQ_fnc_eventCleanup;
    A side event is over (crash crate secured, hostage event ended, corridor outpost fallen):
    CQ_eventCleanup s later, once no player is within CQ_eventCleanupR m, its props and the enemies
    it left behind are removed.
      _things  objects (props, statics, vehicles: their non-player crew goes with them), units and
               groups; already dead / deleted ones are skipped. A vehicle a player is in stays.
    Map buildings (terrain objects) are never touched.
*/
params ["_label", ["_things", []]];
if (!isServer) exitWith {};
// a group's men are listed by name now (a dead man leaves his group soon, an empty group is deleted)
{ if (_x isEqualType grpNull && { !isNull _x }) then { _things append (units _x) } } forEach +_things;
_things = _things arrayIntersect _things;
["%1: over, props and enemies left removed in %2 s", [_label, CQ_eventCleanup]] call CQ_fnc_log;
[_label, _things] spawn {
    params ["_label", "_things"];
    sleep CQ_eventCleanup;
    // ...and only once no player is within CQ_eventCleanupR m of what is left (never under their eyes)
    private _pos = [];
    { if (_x isEqualType grpNull) then { { _pos pushBack _x } forEach units _x } else { _pos pushBack _x } } forEach _things;
    private _waitT = time;
    waitUntil {
        sleep 10;
        _pos = _pos select { !isNull _x };
        (allPlayers findIf { private _p = _x; alive _p && { (_pos findIf { _x distance2D _p < CQ_eventCleanupR }) > -1 } }) == -1
    };
    if (time - _waitT > 15) then { ["%1: players gone, cleanup now (waited %2 s more)", [_label, round (time - _waitT)]] call CQ_fnc_log };
    private _n = 0;
    private _dead = 0;
    private _live = 0;
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
                if (alive _o) then { _live = _live + 1 } else { _dead = _dead + 1 };
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
    ["%1: cleaned up (%2 removed: %3 alive men, %4 bodies, %5 objects)", [_label, _n, _live, _dead, _n - _live - _dead]] call CQ_fnc_log;
};
