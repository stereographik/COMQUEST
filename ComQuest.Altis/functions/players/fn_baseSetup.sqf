/*
    CQ_fnc_baseSetup  (server)
    Creates the player base at CQ_basePos: respawn marker, map markers, arsenal crate.
*/
if (!isServer) exitWith {};

private _base = CQ_basePos;

// Respawn point used by respawn = 3 (BASE)
private _respawn = createMarker ["respawn_west", _base];
_respawn setMarkerType "Empty";

// Map markers
private _hq = createMarker ["cq_base", _base];
_hq setMarkerType "b_hq";
_hq setMarkerColor "ColorWEST";
_hq setMarkerText "Main base";

private _zone = createMarker ["cq_base_zone", _base];
_zone setMarkerShape "ELLIPSE";
_zone setMarkerSize [CQ_baseRadius, CQ_baseRadius];
_zone setMarkerBrush "Border";
_zone setMarkerColor "ColorWEST";

// Arsenal crate (the action is added on each client by CQ_fnc_playerSetup)
private _boxPos = _base findEmptyPosition [3, 60, "B_supplyCrate_F"];
if (_boxPos isEqualTo []) then { _boxPos = _base };

private _box = createVehicle ["B_supplyCrate_F", _boxPos, [], 0, "NONE"];
_box allowDamage false;
clearWeaponCargoGlobal _box;
clearMagazineCargoGlobal _box;
clearItemCargoGlobal _box;
clearBackpackCargoGlobal _box;
missionNamespace setVariable ["CQ_arsenalBox", _box, true];

["Base set up at %1, arsenal at %2", [mapGridPosition _base, mapGridPosition _box]] call CQ_fnc_log;
