/*
    CQ_fnc_carrierMarker  (server)
    Updates the carrier's map marker with what it has left: supplies for new HQs as a
    percentage (CQ_carrierLeft / CQ_carrierHqs).
*/
if (!isServer || { !("cq_carrier" in allMapMarkers) }) exitWith {};
private _pct = round (100 * (CQ_carrierLeft max 0) / (CQ_carrierHqs max 1));
"cq_carrier" setMarkerText format ["CSAT carrier  %1%%", _pct];
