/*
    CQ_fnc_carrierSetup  (server, once at mission start)
    allaroundisland: places the CSAT carrier group's carrier at one of the precomputed sites
    all around Altis (CQ_carrierSites), picked at random and never the site of the previous game
    (CQ_lastCarrierSite, kept in the server's profile). Every air insertion and supply flight
    starts from it (CQ_carrierPos). The site's paired position is the first HQ (CQ_firstHqPos).
    CQ_coastPoint: the first land on the line from the carrier to that HQ, used to choose where
    later root insertions land and by the intro camera.
*/
private _n = count CQ_carrierSites;
private _last = profileNamespace getVariable ["CQ_lastCarrierSite", -1];
private _idx = floor random _n;
if (_n > 1) then { while { _idx == _last } do { _idx = floor random _n } };
if (CQ_carrierSiteForce >= 0 && { CQ_carrierSiteForce < _n }) then { _idx = CQ_carrierSiteForce };
profileNamespace setVariable ["CQ_lastCarrierSite", _idx];
saveProfileNamespace;
CQ_carrierSite = _idx;
(CQ_carrierSites select _idx) params ["_cp", "_hp"];
CQ_firstHqPos = [_hp select 0, _hp select 1, 0];

// the coast: first land from the carrier toward its first HQ
private _dir = _cp getDir _hp;
private _coast = [];
for "_d" from 0 to (_cp distance2D _hp) step 50 do {
    private _p = _cp getPos [_d, _dir];
    if (getTerrainHeightASL _p > 0) exitWith { _coast = [_p select 0, _p select 1, 0] };
};
if (_coast isEqualTo []) then { _coast = CQ_firstHqPos };

CQ_coastPoint = _coast;
CQ_carrierPos = [_cp select 0, _cp select 1, 0];
CQ_carrierDir = (_dir + 90) mod 360;     // broadside to the island
publicVariable "CQ_carrierPos";      // clients: intro camera
publicVariable "CQ_coastPoint";
["Carrier site C%1 of %2 (previous game: %3), first HQ at %4", [_idx + 1, _n, if (_last < 0) then { "none" } else { format ["C%1", _last + 1] }, mapGridPosition CQ_firstHqPos]] call CQ_fnc_log;

isNil {
    private _carrier = createVehicle [CQ_carrierClass, CQ_carrierPos, [], 0, "NONE"];
    _carrier setPosWorld [CQ_carrierPos select 0, CQ_carrierPos select 1, 0];
    _carrier setDir CQ_carrierDir;
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

["CSAT carrier spotted", format ["An enemy carrier group is holding off the %1 coast (grid %2). Expect landings on the %1 coast.",
    ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"] select ((round ((CQ_basePos getDir CQ_carrierPos) / 45)) mod 8),
    mapGridPosition CQ_carrierPos]] call CQ_fnc_announce;
[] spawn { waitUntil { sleep 1; !isNil "CQ_missionStarted" }; sleep 1; ["carrier", []] call CQ_fnc_say };   // once the mission has started (after the intro)
