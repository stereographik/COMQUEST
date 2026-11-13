/*
    CQ_fnc_hostageHeli  (server)
    [_state] call CQ_fnc_hostageHeli;
    A crewed friendly helicopter (CQ_hstHeliClass) on the ground on a clear spot CQ_hstLzR m from
    the hostage, rotors turning, green smoke, LZ marker. Also used when it is lost before he boards.
*/
params ["_s"];
private _h = _s get "hostage";
private _hp = getPosATL _h;
private _lz = [];
CQ_hstLzR params ["_r0", "_r1"];
for "_r" from _r0 to _r1 step 60 do {
    _lz = [_hp, _r, _r + 60, 14, 0, 0.2, 0, [], [[], []]] call BIS_fnc_findSafePos;
    if (_lz isNotEqualTo [] && { count _lz == 2 } && { _lz distance2D _hp <= _r1 }) exitWith {};
    _lz = [];
};
if (_lz isEqualTo []) then { _lz = [_hp, _r1, 12] call CQ_fnc_clearPos; if (_lz isEqualTo []) then { _lz = _hp getPos [_r0, random 360] } };
_lz = [_lz select 0, _lz select 1, 0];

private _old = _s get "heli";
if (!isNull _old) then { { deleteVehicle _x } forEach (crew _old); deleteVehicle _old };

private _v = createVehicle [CQ_hstHeliClass, _lz, [], 0, "NONE"];
_v setDir (_lz getDir _hp);
createVehicleCrew _v;
private _g = group driver _v;
_g setBehaviourStrong "CARELESS";
_g setCombatMode "BLUE";
_g setGroupIdGlobal ["Extraction"];
_v engineOn true;
_v lockCargo false;
_v setVariable ["CQ_hstHeli", true, true];
"SmokeShellGreen" createVehicle _lz;

deleteMarker "cq_hst_lz";
private _m = createMarker ["cq_hst_lz", _lz];
_m setMarkerType "mil_pickup";
_m setMarkerColor "ColorWEST";
_m setMarkerText "Extraction";

_s set ["heli", _v];
_s set ["lz", _lz];
