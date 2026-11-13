/*
    CQ_fnc_mapIconScale  (client, spawned once from initPlayerLocal)
    Every icon marker of the mission is shown at CQ_mapIconScale of its default size (local size,
    re-applied when the server updates a marker). Markers players place themselves are left alone.
*/
if (!hasInterface) exitWith {};
private _s = [CQ_mapIconScale, CQ_mapIconScale];
while { true } do {
    {
        if (markerShape _x == "ICON" && { (_x find "_USER_DEFINED") != 0 } && { (markerSize _x) isEqualTo [1, 1] }) then { _x setMarkerSizeLocal _s };
    } forEach allMapMarkers;
    sleep 1;
};
