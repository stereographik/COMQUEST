/*
    CQ_fnc_mapIconScale  (client, spawned once from initPlayerLocal)
    Every icon marker of the mission is shown at CQ_mapIconScale of its default size (local size,
    re-applied when the server updates a marker), and its text starts with a blank so it does not
    touch the icon. Markers players place themselves are left alone.
*/
if (!hasInterface) exitWith {};
private _s = [CQ_mapIconScale, CQ_mapIconScale];
while { true } do {
    {
        if (markerShape _x == "ICON" && { (_x find "_USER_DEFINED") != 0 }) then {
            if ((markerSize _x) isEqualTo [1, 1]) then { _x setMarkerSizeLocal _s };
            // a blank before every text so it does not touch the icon (re-applied when the server rewrites it)
            private _t = markerText _x;
            if (_t != "" && { (_t select [0, 1]) != " " }) then { _x setMarkerTextLocal (" " + _t) };
        };
    } forEach allMapMarkers;
    sleep 1;
};
