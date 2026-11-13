/*
    CQ_fnc_debugHqDash  (server, from CQ_fnc_debugCmd)
    [_hq] call CQ_fnc_debugHqDash  ->  structured text for the debug panel's HQ dashboard column
    Phase and timers, objectives, forces (infantry by role, vehicles, air, snipers, guerillas,
    support), resources (ammo, fuel, depot, tanker, field truck) and the build truck.
*/
params ["_hq"];
if (count _hq == 0) exitWith { "<t size='0.9' color='#A6A381'>Select an HQ in the list to see its dashboard.</t>" };

private _id = _hq get "id";
private _acc = "#918C3B"; private _mut = "#A6A381"; private _bad = "#BA392C"; private _ok = "#8FD16A";
private _head = { format ["<br/><t size='0.95' color='%1' font='PuristaMedium'>%2</t><br/>", _acc, _this] };
private _row = { params ["_k", "_v", ["_c", "#F2F1DF"]]; format ["<t color='%1'>%2</t><t align='right' color='%3'>%4</t><br/>", _mut, _k, _c, _v] };
private _yn = { params ["_alive", ["_yes", "up"], ["_no", "down"]]; [[_no, _bad], [_yes, _ok]] select _alive };
private _ago = { private _s = round (time - _this); if (_s > 1e5) exitWith { "never" }; if (_s < 120) then { format ["%1 s", _s] } else { format ["%1 min", round (_s / 60)] } };
private _men = { params ["_gs"]; { alive _x } count (flatten (_gs apply { if (isNull _x) then { [] } else { units _x } })) };

private _t = format ["<t size='1.15' font='PuristaMedium' color='%1'>HQ #%2  %3</t><br/>", _acc, _id, _hq getOrDefault ["name", ""]];

// ---- phase
private _st = _hq get "state";
_t = _t + ("PHASE" call _head);
_t = _t + (["State", format ["%1 (%2)", _st, (_hq get "stateT") call _ago], [_ok, _bad] select !(_st in CQ_activeStates)] call _row);
_t = _t + (["Role", if (_id == CQ_hubId) then { "MAIN HQ" } else { if ((_hq get "parent") > -1) then { format ["child of #%1", _hq get "parent"] } else { "root" } }] call _row);
_t = _t + (["Grid / age", format ["%1  /  %2", mapGridPosition (_hq get "pos"), (_hq get "born") call _ago]] call _row);
_t = _t + (["Build", if (_hq get "buildDone") then { "done 6/6" } else { format ["stage %1/6", _hq getOrDefault ["buildStage", 0]] }] call _row);
private _nv = _hq getOrDefault ["nerv", 0];
_t = _t + (["Nerves", format ["%1%2", CQ_nervNames param [_nv, "?"], ["", "  ALARM"] select (_hq getOrDefault ["alarm", false])], [_mut, _bad] select (_nv >= 3)] call _row);
_t = _t + (["Data link", ["connected", "CUT OFF"] select (_hq getOrDefault ["isolated", false]), [_ok, _bad] select (_hq getOrDefault ["isolated", false])] call _row);
_t = _t + (["Last contact", (_hq getOrDefault ["lastContactT", -1e6]) call _ago] call _row);
private _nw = _hq getOrDefault ["nextWaveT", 0];
if (_nw > time) then { _t = _t + (["Next wave", format ["in %1 s", round (_nw - time)]] call _row) };
_t = _t + (["Site tolerance", str (_hq getOrDefault ["siteLevel", 0])] call _row);

// ---- objectives
_t = _t + ("OBJECTIVES" call _head);
private _cmd = _hq get "commander";
_t = _t + (["Commander", if (_hq get "cmdCaptured") then { "CAPTURED" } else { if (isNull _cmd) then { "not yet" } else { (alive _cmd) call _yn select 0 } },
    if (_hq get "cmdCaptured" || { !isNull _cmd && { !alive _cmd } }) then { _bad } else { _ok }] call _row);
private _r = _hq get "radio";
_t = _t + (["Radio tower", if (isNull _r) then { "not yet" } else { if (_hq getOrDefault ["radioHacked", false]) then { "HACKED" } else { (alive _r) call _yn select 0 } },
    if (!isNull _r && { !alive _r || { _hq getOrDefault ["radioHacked", false] } }) then { _bad } else { _ok }] call _row);
private _inst = (_hq get "installations") select { !isNull _x };
{
    _x params ["_type", "_label"];
    private _all = _inst select { (_x getVariable ["CQ_objType", ""]) == _type };
    if (_all isNotEqualTo []) then {
        private _up = { alive _x && { !(_x getVariable ["CQ_hacked", false]) } } count _all;
        _t = _t + ([_label, format ["%1/%2", _up, count _all], [_ok, _bad] select (_up < count _all)] call _row);
    };
} forEach [["AA", "AA pits"], ["HMG", "HMG tower"]];
{
    _x params ["_k", "_label"];
    private _o = _hq getOrDefault [_k, objNull];
    _t = _t + ([_label, if (isNull _o) then { "not yet" } else { (alive _o) call _yn select 0 }, if (!isNull _o && { !alive _o }) then { _bad } else { _ok }] call _row);
} forEach [["depot", "Supply depot"], ["tanker", "Fuel tanker"]];

// ---- forces
_t = _t + ("FORCES" call _head);
private _inf = (_hq get "infantry") select { !isNull _x && { ({ alive _x } count units _x) > 0 } };
_t = _t + (["Infantry", format ["%1 men, %2 groups", [_inf] call _men, count _inf]] call _row);
private _roles = createHashMap;
{ private _ro = _x getVariable ["CQ_role", "?"]; _roles set [_ro, (_roles getOrDefault [_ro, [0, 0]]) vectorAdd [1, { alive _x } count units _x]] } forEach _inf;
{ _t = _t + ([format ["   %1", _x], format ["%1 men / %2 gr", _y select 1, _y select 0]] call _row) } forEach _roles;
private _cg = _hq get "cmdGroup";
_t = _t + (["Command group", format ["%1 men", [[_cg]] call _men]] call _row);
private _veh = (_hq get "vehicles") select { alive _x };
private _vt = createHashMap;
{ private _n = getText (configOf _x >> "displayName"); _vt set [_n, (_vt getOrDefault [_n, 0]) + 1] } forEach _veh;
_t = _t + (["Vehicles", str count _veh] call _row);
{ _t = _t + ([format ["   %1", _x], str _y] call _row) } forEach _vt;
private _air = CQ_air select { alive (_x get "veh") && { (_x get "homeId") == _id } };
_t = _t + (["Aircraft (home)", str count _air] call _row);
{ _t = _t + ([format ["   %1", getText (configOf (_x get "veh") >> "displayName")], _x get "state"] call _row) } forEach _air;
private _sn = (_hq getOrDefault ["snipers", []]) select { alive _x };
_t = _t + (["Snipers", str count _sn] call _row);
private _gu = (_hq getOrDefault ["guerilla", []]) select { !isNull _x };
_t = _t + (["Guerillas", format ["%1 men", [_gu] call _men]] call _row);
private _sup = (_hq getOrDefault ["support", []]) select { !isNull _x };
_t = _t + (["Support crews", format ["%1 men", [_sup apply { if (_x isEqualType grpNull) then { _x } else { group _x } }] call _men]] call _row);

// ---- resources
_t = _t + ("RESOURCES" call _head);
private _cap = _hq get "cap";
_t = _t + (["Ammo", format ["%1 / %2", round (_hq get "stock"), _cap], [_ok, _bad] select ((_hq get "stock") < _cap * 0.25)] call _row);
_t = _t + (["Fuel", format ["%1 / %2", round (_hq get "fuel"), _cap], [_ok, _bad] select ((_hq get "fuel") < _cap * 0.25)] call _row);
private _ft = _hq getOrDefault ["fieldTruck", objNull];
_t = _t + (["Field supply truck", if (isNull _ft) then { "none" } else { if (alive _ft) then { ["parked", "on a run"] select (_hq getOrDefault ["fieldRun", false]) } else { "destroyed" } }] call _row);
_t = _t + (["Supply truck inbound", ["no", "yes"] select (_hq getOrDefault ["truckInbound", false])] call _row);

// ---- build truck
if !(_hq get "buildDone") then {
    _t = _t + ("BUILD TRUCK" call _head);
    private _bt = _hq getOrDefault ["buildTruck", objNull];
    _t = _t + (["Truck", if (alive _bt) then { format ["%1 m from the site", round (_bt distance2D (_hq get "pos"))] } else { ["none", "incoming"] select (_hq getOrDefault ["btIncoming", false] || { _hq getOrDefault ["btPending", false] }) }, [_bad, _ok] select (alive _bt)] call _row);
    _t = _t + (["Squad", format ["%1 men", [[_hq getOrDefault ["btSquad", grpNull]]] call _men]] call _row);
    _t = _t + (["Trucks lost / drops used", format ["%1 / %2 of %3", _hq getOrDefault ["btKills", 0], missionNamespace getVariable ["CQ_btDrops", 0], CQ_btMaxDrops]] call _row);
};
format ["<t size='0.82'>%1</t>", _t]
