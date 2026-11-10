/*
    CQ_fnc_carrierSetup  (server, once at mission start)
    Places the CSAT carrier group's carrier off the EAST coast of Altis, at a random point:
      - a random latitude in CQ_coastBand
      - scanning west from the map's east edge to the first land = the coast point
      - then CQ_carrierOffshore metres back out to sea, in water deeper than 25 m
    Every air insertion and supply flight starts from it (CQ_carrierPos).
    Also stores CQ_coastPoint, used to choose where root insertions land.
*/
private _y = (CQ_coastBand select 0) + random ((CQ_coastBand select 1) - (CQ_coastBand select 0));

private _coast = [];
for "_x" from (worldSize - 200) to (worldSize * 0.5) step -100 do {
    if (getTerrainHeightASL [_x, _y] > 0) exitWith { _coast = [_x, _y, 0] };
};
if (_coast isEqualTo []) then { _coast = [worldSize * 0.85, _y, 0] };

private _sea = _coast vectorAdd [CQ_carrierOffshore, 0, 0];
private _guard = 0;
while { getTerrainHeightASL _sea > -25 && { _guard < 30 } } do { _sea = _sea vectorAdd [200, 0, 0]; _guard = _guard + 1 };

CQ_coastPoint = _coast;
CQ_carrierPos = [_sea select 0, _sea select 1, 0];
publicVariable "CQ_carrierPos";      // clients: intro camera
publicVariable "CQ_coastPoint";

isNil {
    private _carrier = createVehicle [CQ_carrierClass, CQ_carrierPos, [], 0, "NONE"];
    _carrier setPosWorld [CQ_carrierPos select 0, CQ_carrierPos select 1, 0];
    _carrier setDir 0;
    _carrier allowDamage false;
    CQ_carrier = _carrier;
};
// Re-align the carrier's sub-objects once its own init has assembled them
[] spawn {
    sleep 2;
    if (!isNil "BIS_fnc_Carrier01PosUpdate") then { [CQ_carrier] call BIS_fnc_Carrier01PosUpdate };
    ["Carrier placed at %1 (%2 m off the coast at %3), %4 parts", [mapGridPosition CQ_carrierPos,
        round (CQ_carrierPos distance2D CQ_coastPoint), mapGridPosition CQ_coastPoint,
        count (CQ_carrier getVariable ["bis_carrierParts", []])]] call CQ_fnc_log;
};

// carrier marker, always shown: what the carrier has left (CQ_fnc_carrierMarker)
private _m = createMarker ["cq_carrier", CQ_carrierPos];
_m setMarkerType "o_naval";
_m setMarkerColor "ColorOPFOR";
_m setMarkerText "CSAT carrier group";
CQ_carrierLeft = CQ_carrierHqs;
CQ_specialLeft = createHashMapFromArray [["medic", CQ_specialRespawns], ["engineer", CQ_specialRespawns]];
call CQ_fnc_carrierMarker;

["CSAT carrier spotted", format ["An enemy carrier group is holding off the east coast (grid %1). Expect landings on the east coast.",
    mapGridPosition CQ_carrierPos]] call CQ_fnc_announce;
[] spawn { sleep 15; ["carrier", []] call CQ_fnc_say };   // let the players load in first
