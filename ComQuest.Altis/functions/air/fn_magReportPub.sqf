/*
    CQ_fnc_magReportPub  (server)
    The tablet copy of MAGPIE's picture (CQ_fnc_magReportUi): rebuilt with every report and with
    every new identification in between (CQ_fnc_magTick).
    CQ_magReportPub = [time of the last report (serverTime, -1 none yet), [HQ news of that report],
                       [[cat, type, hdg, spd, owner, inSight, new], ...], revision]
      new  identified by the last report, or since it (not reported yet)   -> LAST SEEN tab
      all  every enemy still alive MAGPIE has identified                    -> GLOBAL SITUATION tab
    Infantry: one row per squad. Owner: the HQ owning the squad / vehicle, else the nearest known AO.
*/
if (!isServer) exitWith {};
private _newObjs = missionNamespace getVariable ["CQ_magLastNewObjs", []];
private _news = missionNamespace getVariable ["CQ_magLastNews", []];
private _aos = (values CQ_hqs) select { (_x get "state") in CQ_activeStates && { (_x get "id") in CQ_magHqSeen || { _x getOrDefault ["revealed", false] } } };
private _own = createHashMap;                  // group -> HQ name
{
    private _nm = [_x get "id"] call CQ_fnc_objName;
    { if (!isNull _x) then { _own set [_x, _nm] } } forEach ((_x getOrDefault ["infantry", []]) + [_x getOrDefault ["cmdGroup", grpNull], _x getOrDefault ["escort", grpNull]]);
} forEach (values CQ_hqs);
private _ownerOf = {
    params ["_o", "_p"];
    private _n = _own getOrDefault [group _o, ""];
    if (_n == "") then { private _hid = _o getVariable ["CQ_hqId", -1]; if (_hid > -1) then { _n = [_hid] call CQ_fnc_objName; if (isNil "_n") then { _n = "" } } };
    if (_n == "") then {
        private _best = CQ_magAoRange;
        { private _d = (_x get "pos") distance2D _p; if (_d < _best) then { _best = _d; _n = [_x get "id"] call CQ_fnc_objName; if (isNil "_n") then { _n = "" } } } forEach _aos;
    };
    if (isNil "_n" || { !(_n isEqualType "") } || { _n == "" }) then { "-" } else { _n }
};
private _rows = [];
private _squads = createHashMap;               // infantry: group -> [records]
{
    _x params ["_o", "", "_tl", "_p", "_c", ["_rep", true], ["_hs", [0, 0]]];
    if (!alive _o) then { continue };
    private _vis = time - _tl <= CQ_magDetectEvery + 2;
    if (_c == "inf") then {
        private _g = group _o;
        private _k = [_g, _o] select (isNull _g);
        _squads set [_k, (_squads getOrDefault [_k, []]) + [_x]];
    } else {
        private _hd = [_hs select 0, round getDir _o] select _vis;
        private _sp = [_hs select 1, round speed _o] select _vis;
        _rows pushBack [_c, getText (configOf _o >> "displayName"), _hd mod 360, _sp, [_o, _p] call _ownerOf, _vis, _o in _newObjs || { !_rep }];
    };
} forEach (values CQ_magSeen);
{
    private _recs = _y;
    private _vis = _recs findIf { time - (_x select 2) <= CQ_magDetectEvery + 2 } > -1;
    private _r = _recs select 0;
    private _o = _r select 0;
    private _hs = _r param [6, [0, 0]];
    private _hd = [_hs select 0, round getDir _o] select _vis;
    private _sp = [_hs select 1, round speed _o] select _vis;
    _rows pushBack ["inf", format ["Infantry squad x%1", count _recs], _hd mod 360, _sp, [_o, _r select 3] call _ownerOf, _vis, _recs findIf { (_x select 0) in _newObjs || { !(_x select 5) } } > -1];
} forEach _squads;
CQ_magReportRev = (missionNamespace getVariable ["CQ_magReportRev", 0]) + 1;
CQ_magReportPub = [missionNamespace getVariable ["CQ_magLastReportST", -1], _news, _rows, CQ_magReportRev];
publicVariable "CQ_magReportPub";
