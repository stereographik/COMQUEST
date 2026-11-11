/*
    CQ_fnc_callReinf  (server)
    [_hq, _contactPos] call CQ_fnc_callReinf;
    The HQ that spotted players calls for help:
      - the closest armed helicopters with ammo take off to hunt (search & destroy)
      - every HQ linked to it by radio (both radios standing, within CQ_commsRange) sends a
        share of its available troops, bigger the closer it is to the contact (CQ_qrfShares)
      - no radio tower (not built yet, or destroyed): nobody hears the call; only the spotting
        HQ's own forces and squads near the contact respond, no child HQ rallies to a root
    Each HQ keeps at least CQ_minDefenders infantry at home. Groups (and helis) short of ammo
    (under CQ_minAmmoToAdvance) never go forward.
    Also:
      - squads patrolling within CQ_helpRadius of the contact join in (small-perimeter help)
      - the squad that made contact is watched: if it is mostly wiped out within
        CQ_flareWindow, it fires a red flare -> heavy support (CQ_fnc_flareSupport)
      - contact at a ROOT HQ (the first HQ of an insertion): every child HQ rallies to it
*/
params ["_src", "_pos", ["_spotter", grpNull]];

private _srcId = _src get "id";
_src set ["lastContactT", time];
// No radio tower (not built yet, or destroyed): nobody hears the call. Only the HQ's own
// forces and the squads close to the contact respond.
private _srcRadio = alive (_src get "radio") && { !(_src getOrDefault ["isolated", false]) };   // nGD: isolated = cut off, nobody hears it
private _noRadioWhy = switch (true) do {
    case (alive (_src get "radio")): { "cut off from the network" };
    case (!isNull (_src getOrDefault ["radioHacked", objNull])): { "radio tower hacked" };
    case (isNull (_src get "radio")): { "no radio tower yet" };
    default { "radio tower destroyed" };
};

["Enemy contact reported", format ["HQ #%1 spotted friendlies near grid %2, calling reinforcements", _srcId, mapGridPosition _pos]] call CQ_fnc_announce;
["contact", [format ["HQ%1", _srcId]], _src] call CQ_fnc_say;   // arg only keys the cooldown

private _report = [];

// --- Armed helicopters: the CQ_airQrfMax closest with ammo, parked within CQ_airQrfRange.
//     The spotting HQ's own Orca always answers; others need the radio link.
private _air = CQ_air select {
    private _v = _x get "veh";
    (_x get "kind") == "armed" && { (_x get "state") in ["parked", "toPark", "patrolling"] } && { alive _v }
    && { ([_v] call CQ_fnc_vehAmmoLevel) >= CQ_minAmmoToAdvance - 0.1 }
    && { fuel _v >= CQ_airMinFuelToHunt }
    && { _v distance2D _pos < CQ_airQrfRange }
    && { _srcRadio || { (_x get "homeId") == _srcId } }
};
_air = [_air, [], { (_x get "veh") distance2D _pos }, "ASCEND"] call BIS_fnc_sortBy;
{
    if (_forEachIndex >= CQ_airQrfMax) exitWith {};
    private _v = _x get "veh";
    private _hg = _x get "grp";
    [_hg] call CQ_fnc_clearWaypoints;
    _v engineOn true;
    _v flyInHeight 60;
    _hg setBehaviour "COMBAT";
    _hg setCombatMode "RED";
    private _wp = _hg addWaypoint [_pos, 100];
    _wp setWaypointType "SAD";
    _x set ["state", "hunting"];
    _x set ["until", time + CQ_heliHuntTime];
    _x set ["nearT", -1];
    _report pushBack format ["%1 (%2 m)", getText (configOf _v >> "displayName"), round (_v distance2D _pos)];
} forEach _air;

// --- Ground QRF from every responding HQ
{
    private _hq = _y;
    private _isSrc = (_hq get "id") == _srcId;
    if !((_hq get "state") in (CQ_activeStates - ["Inbound"])) then { continue };

    private _d = (_hq get "pos") distance2D _pos;
    private _linked = _srcRadio
        && { alive (_hq get "radio") } && { !(_hq getOrDefault ["isolated", false]) }
        && { (_hq get "pos") distance2D (_src get "pos") <= CQ_commsRange };
    if (!_isSrc && !_linked) then { continue };

    private _share = 0;
    { _x params ["_maxD", "_s"]; if (_d < _maxD) exitWith { _share = _s } } forEach CQ_qrfShares;
    if (_share <= 0) then { continue };

    private _inf = (_hq get "infantry") select { ({ alive _x } count units _x) > 0 };
    private _total = [_inf] call CQ_fnc_aliveCount;
    private _want = round (_total * _share) min (_total - CQ_minDefenders);
    if (_want <= 0) then { continue };

    // Available: patrols, fresh reinforcements and perimeter squads, never the defend squad
    private _cands = _inf select { (_x getVariable ["CQ_role", ""]) in ["patrol", "reinf", "secure"] && { ([_x] call CQ_fnc_infAmmo) >= CQ_minAmmoToAdvance } };
    private _sent = 0;
    private _nGroups = 0;
    {
        if (_sent >= _want) exitWith {};
        private _g = _x;
        [_g] call CQ_fnc_clearWaypoints;
        _g setVariable ["CQ_role", "qrf"];
        _g setVariable ["CQ_qrfUntil", time + CQ_qrfTime];
        _g setBehaviour "AWARE";
        _g setSpeedMode "FULL";
        private _wp = _g addWaypoint [_pos, 80];
        _wp setWaypointType "SAD";
        _sent = _sent + ({ alive _x } count units _g);
        _nGroups = _nGroups + 1;
    } forEach _cands;

    if (_sent > 0) then {
        _report pushBack format ["HQ #%1: %2 men (%3 m away)", _hq get "id", _sent, round _d];
    };
} forEach CQ_hqs;

// --- small-perimeter help: patrolling squads close to the contact push in
{
    private _hq = _y;
    if !((_hq get "state") in CQ_activeStates) then { continue };
    {
        private _g = _x;
        if ((_g getVariable ["CQ_role", ""]) in ["patrol", "reinf"] && { (leader _g) distance2D _pos < CQ_helpRadius }
            && { ([_g] call CQ_fnc_infAmmo) >= CQ_minAmmoToAdvance }) then {
            [_g] call CQ_fnc_clearWaypoints;
            _g setVariable ["CQ_role", "qrf"];
            _g setVariable ["CQ_qrfUntil", time + CQ_qrfTime];
            _g setBehaviour "AWARE";
            _g setSpeedMode "FULL";
            (_g addWaypoint [_pos, 60]) setWaypointType "SAD";
            _report pushBack format ["%1 nearby (%2 m)", groupId _g, round ((leader _g) distance2D _pos)];
        };
    } forEach (_hq get "infantry");
} forEach CQ_hqs;

// --- the spotting squad is watched: wiped quickly -> red flare, heavy support
if (!isNull _spotter && { !(_spotter getVariable ["CQ_watched", false]) }) then {
    _spotter setVariable ["CQ_watched", true];
    [_spotter, _src, _pos] spawn {
        params ["_g", "_hq", "_pos"];
        private _n0 = { alive _x } count units _g;
        private _t0 = time;
        waitUntil { sleep 3; time - _t0 > CQ_flareWindow || { ({ alive _x } count units _g) <= floor (_n0 * CQ_flareLossShare) } };
        _g setVariable ["CQ_watched", false];
        if (time - _t0 <= CQ_flareWindow && { _n0 >= 2 }) then { [_hq, _pos, _g] call CQ_fnc_flareSupport };
    };
};

// --- root HQ attacked: every child HQ sends everything it can spare to defend it
private _root = _src;
private _guard = 0;
while { (_root get "parent") > -1 && { _guard < 20 } } do {
    _guard = _guard + 1;
    private _p = CQ_hqs getOrDefault [_root get "parent", createHashMap];
    if (count _p == 0) exitWith {};
    _root = _p;
};
if (_srcRadio && { (_src get "parent") == -1 } && { time - (_src get "rootDefendT") > CQ_rootDefendCooldown }) then {
    _src set ["rootDefendT", time];
    private _kids = (values CQ_hqs) select {
        (_x get "state") in CQ_activeStates && { (_x get "id") != _srcId } && {
            private _r = _x; private _k = 0;
            while { (_r get "parent") > -1 && { (_r get "parent") != _srcId } && { _k < 20 } } do {
                _k = _k + 1; _r = CQ_hqs getOrDefault [_r get "parent", createHashMap];
                if (count _r == 0) exitWith {};
            };
            (_r getOrDefault ["parent", -1]) == _srcId
        } && { alive (_x get "radio") } && { !(_x getOrDefault ["isolated", false]) }
    };
    {
        private _kid = _x;
        private _gs = (_kid get "infantry") select { (_x getVariable ["CQ_role", ""]) in ["patrol", "reinf", "qrf"] && { ({ alive _x } count units _x) > 0 } };
        if (_gs isNotEqualTo []) then { [_gs, _kid, _src, "rootDefend"] spawn CQ_fnc_moveGroups };
    } forEach _kids;
    if (_kids isNotEqualTo []) then {
        ["ROOT HQ UNDER ATTACK", format ["HQ #%1 (root) attacked: %2 child HQs send their troops to defend it", _srcId, count _kids]] call CQ_fnc_announce;
        ["rootDefend", [[_srcId] call CQ_fnc_objName], _src] call CQ_fnc_say;
    };
};

if (_report isEqualTo []) then {
    ["QRF", format ["HQ #%1: nobody available to respond%2", _srcId, ["", format [" (%1)", _noRadioWhy]] select !_srcRadio]] call CQ_fnc_announce;
} else {
    ["QRF dispatched", (_report joinString ", ") + (["", format [". %1: no help from other HQs", _noRadioWhy]] select !_srcRadio)] call CQ_fnc_announce;
};
