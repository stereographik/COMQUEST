/*
    CQ_fnc_debugHqInv  (server, from CQ_fnc_debugCmd)
    [_hq] call CQ_fnc_debugHqInv  ->  structured text for the debug panel's HQ INVENTORY column:
    the selected HQ's stocks, where its men and vehicles are (distance rings around the HQ), and
    the full list of its groups, vehicles, aircraft and installations.
*/
params ["_hq"];
if (count _hq == 0) exitWith { "<t size='0.9' color='#A6A381'>Select an HQ in the list to see its inventory.</t>" };

private _id = _hq get "id";
private _c = _hq get "pos";
private _acc = "#918C3B"; private _mut = "#A6A381"; private _bad = "#BA392C"; private _ok = "#8FD16A"; private _txt = "#F2F1DF";
private _head = { format ["<br/><t size='0.95' color='%1' font='PuristaMedium'>%2</t><br/>", _acc, _this] };
private _row = { params ["_k", "_v", ["_col", _txt]]; format ["<t color='%1'>%2</t><t align='right' color='%3'>%4</t><br/>", _mut, _k, _col, _v] };
private _ring = { private _d = _this distance2D _c; [[2, 1] select (_d < 1000), 0] select (_d < 300) };   // 0 core, 1 perimeter, 2 away
private _pct = { format ["%1%%", round (_this * 100)] };

private _t = format ["<t size='1.05' font='PuristaMedium' color='%1'>HQ #%2  %3</t><br/>", _acc, _id, _hq getOrDefault ["name", ""]];

// ---- stocks
_t = _t + ("STOCKS" call _head);
private _cap = _hq get "cap";
_t = _t + (["Ammo", format ["%1 / %2", round (_hq get "stock"), _cap], [_ok, _bad] select ((_hq get "stock") < _cap * 0.25)] call _row);
_t = _t + (["Fuel", format ["%1 / %2", round (_hq get "fuel"), _cap], [_ok, _bad] select ((_hq get "fuel") < _cap * 0.25)] call _row);
{
    _x params ["_k", "_label"];
    private _o = _hq getOrDefault [_k, objNull];
    _t = _t + ([_label, if (isNull _o) then { "none" } else { if (alive _o) then { format ["%1 m, %2 dmg", round (_o distance2D _c), (damage _o) call _pct] } else { "destroyed" } }, [_ok, _bad] select (isNull _o || { !alive _o })] call _row);
} forEach [["depot", "Supply depot"], ["tanker", "Fuel tanker"], ["fieldTruck", "Field supply truck"]];
_t = _t + (["Supply truck inbound", ["no", "yes"] select (_hq getOrDefault ["truckInbound", false])] call _row);

// ---- distribution: men and vehicles by distance from the HQ
private _inf = (_hq get "infantry") select { !isNull _x && { ({ alive _x } count units _x) > 0 } };
private _extra = [_hq get "cmdGroup"] + ((_hq getOrDefault ["guerilla", []]) select { !isNull _x });
private _men = flatten ((_inf + _extra) apply { if (isNull _x) then { [] } else { (units _x) select { alive _x } } });
_men append ((_hq getOrDefault ["snipers", []]) select { alive _x && { !(_x in _men) } });
private _veh = (_hq get "vehicles") select { alive _x };
private _mr = [0, 0, 0]; { private _i = _x call _ring; _mr set [_i, (_mr select _i) + 1] } forEach _men;
private _vr = [0, 0, 0]; { private _i = _x call _ring; _vr set [_i, (_vr select _i) + 1] } forEach _veh;
_t = _t + ("DISTRIBUTION (core < 300 m < perimeter < 1 km < away)" call _head);
_t = _t + (["Men", format ["%1  |  %2  |  %3   (%4)", _mr select 0, _mr select 1, _mr select 2, count _men]] call _row);
_t = _t + (["Vehicles", format ["%1  |  %2  |  %3   (%4)", _vr select 0, _vr select 1, _vr select 2, count _veh]] call _row);

// ---- groups
_t = _t + (format ["GROUPS (%1)", count _inf] call _head);
{
    private _g = _x;
    private _l = leader _g;
    private _alive = { alive _x } count units _g;
    private _wp = if (currentWaypoint _g < count waypoints _g) then { waypointType [_g, currentWaypoint _g] } else { "-" };
    private _inV = { alive _x && { vehicle _x != _x } } count units _g;
    _t = _t + ([format ["%1  <t color='%2'>%3</t>", groupId _g, _mut, _g getVariable ["CQ_role", "?"]],
        format ["%1/%2  %3 m  %4%5", _alive, count units _g, round (_l distance2D _c), _wp, ["", format ["  (%1 mounted)", _inV]] select (_inV > 0)],
        [_txt, _bad] select (_alive < (count units _g) / 2)] call _row);
} forEach (_inf select [0, 30]);
if (count _inf > 30) then { _t = _t + ([format ["... %1 more", count _inf - 30], ""] call _row) };

// ---- vehicles
_t = _t + (format ["VEHICLES (%1)", count _veh] call _head);
{
    private _v = _x;
    private _crew = { alive _x } count crew _v;
    _t = _t + ([getText (configOf _v >> "displayName"),
        format ["crew %1  fuel %2  dmg %3  %4  %5 m", _crew, (fuel _v) call _pct, (damage _v) call _pct, ["no ammo", "armed"] select (someAmmo _v), round (_v distance2D _c)],
        [[_txt, _bad] select (damage _v > 0.5 || { !canMove _v }), _mut] select (_crew == 0)] call _row);
} forEach (_veh select [0, 25]);

// ---- aircraft based here
private _air = CQ_air select { alive (_x get "veh") && { (_x get "homeId") == _id } };
_t = _t + (format ["AIRCRAFT (%1)", count _air] call _head);
{
    private _v = _x get "veh";
    _t = _t + ([getText (configOf _v >> "displayName"), format ["%1  fuel %2  dmg %3  %4", _x get "state", (fuel _v) call _pct, (damage _v) call _pct, ["no ammo", "armed"] select (someAmmo _v)]] call _row);
} forEach _air;

// ---- installations
private _inst = (_hq get "installations") select { !isNull _x };
_t = _t + (format ["INSTALLATIONS (%1)", count _inst] call _head);
{
    private _o = _x;
    private _st = if (!alive _o) then { "destroyed" } else { if (_o getVariable ["CQ_hacked", false]) then { "hacked" } else { "up" } };
    _t = _t + ([_o getVariable ["CQ_objType", typeOf _o], format ["%1%2  %3 m", _st, ["", "  spotted"] select (_o getVariable ["CQ_spotted", false]), round (_o distance2D _c)], [_ok, _bad] select (_st != "up")] call _row);
} forEach _inst;

"<t size='0.62'>" + _t + "</t>"
