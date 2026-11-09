/*
    CQ_fnc_carrierMarker  (server)
    Updates the carrier's map marker with what it has left: supplies for new HQs as a
    percentage (CQ_carrierLeft / CQ_carrierHqs) and the medic / engineer team respawns.
*/
if (!isServer || { !("cq_carrier" in allMapMarkers) }) exitWith {};
private _pct = round (100 * (CQ_carrierLeft max 0) / (CQ_carrierHqs max 1));
private _sp = missionNamespace getVariable ["CQ_specialLeft", createHashMap];
"cq_carrier" setMarkerText format ["CSAT carrier  %1%%   |   medics %2   engineers %3", _pct,
    _sp getOrDefault ["medic", CQ_specialRespawns], _sp getOrDefault ["engineer", CQ_specialRespawns]];
