/*
    CQ_fnc_debugRunwaySite  (server, DEBUG only)
    Site for the 1st root insertion, at the end of the airport runway so you can watch it.
    Priority: an Eden marker named "cq_debug_site", else the runway threshold read from the
    map config (CfgWorlds >> Altis >> ilsPosition), else 900 m west of the base.
*/
if ("cq_debug_site" in allMapMarkers) exitWith {
    ["Debug site: marker cq_debug_site at %1", [mapGridPosition getMarkerPos "cq_debug_site"]] call CQ_fnc_log;
    getMarkerPos "cq_debug_site"
};

private _ils = getArray (configFile >> "CfgWorlds" >> worldName >> "ilsPosition");
["Debug site: ilsPosition %1, ilsDirection %2", [_ils, getArray (configFile >> "CfgWorlds" >> worldName >> "ilsDirection")]] call CQ_fnc_log;

private _anchor = if (count _ils >= 2) then { [_ils select 0, _ils select 1, 0] } else { CQ_basePos getPos [900, 270] };

private _site = [_anchor, 0, 350, false, 40] call CQ_fnc_findSite;
if (_site isEqualTo []) then { _site = _anchor; CQ_lastSiteLevel = 5 };

["Debug site chosen at %1, %2 m from base", [mapGridPosition _site, round (_site distance2D CQ_basePos)]] call CQ_fnc_log;
_site
