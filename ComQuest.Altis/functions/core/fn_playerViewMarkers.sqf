/*
    CQ_fnc_playerViewMarkers  (server)
    "Final player view" (debug panel): debug-only map markers (exact HQ positions, debug HQ
    areas and labels, debug sites) are hidden while CQ_playerView is on, shown again when it is
    off. Called by the toggle and every 15 s (CQ_fnc_actTick) for markers made later.
    Captured-commander intel markers (cq_intel_*) are real player intel and stay visible.
*/
if (!isServer) exitWith {};
private _hide = missionNamespace getVariable ["CQ_playerView", false];
{
    if ((_x select [0, 6]) == "cq_hq_" || { (_x select [0, 7]) == "cq_dbg_" }) then {
        _x setMarkerAlpha ([1, 0] select _hide);
    };
} forEach allMapMarkers;
