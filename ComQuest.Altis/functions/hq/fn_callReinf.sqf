/*
    CQ_fnc_callReinf  (server)
    [_hq, _contactPos] call CQ_fnc_callReinf;
    The HQ that spotted players calls for help:
      - the closest armed helicopters with ammo take off to hunt (search & destroy)
      - every HQ linked to it by radio (both radios standing, within CQ_commsRange) sends a
        share of its available troops, bigger the closer it is to the contact (CQ_qrfShares)
      - no radio: only the spotting HQ's own forces respond
    Each HQ keeps at least CQ_minDefenders infantry at home. Groups (and helis) short of ammo
    (under CQ_minAmmoToAdvance) never go forward.
*/
params ["_src", "_pos"];

private _srcId = _src get "id";
_src set ["lastContactT", time];
private _srcRadio = alive (_src get "radio") || { !(_src get "buildDone") };   // before the tower exists, they use field radios

["Enemy contact reported", format ["HQ #%1 spotted friendlies near grid %2, calling reinforcements", _srcId, mapGridPosition _pos]] call CQ_fnc_announce;

private _report = [];

// --- Armed helicopters: the CQ_airQrfMax closest with ammo, parked within CQ_airQrfRange.
//     The spotting HQ's own Orca always answers; others need the radio link.
private _air = CQ_air select {
    private _v = _x get "veh";
    (_x get "kind") == "armed" && { (_x get "state") in ["parked", "toPark"] } && { alive _v }
    && { ([_v] call CQ_fnc_vehAmmoLevel) >= CQ_minAmmoToAdvance - 0.1 }
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
    _x set ["landing", false];
    _report pushBack format ["%1 (%2 m)", getText (configOf _v >> "displayName"), round (_v distance2D _pos)];
} forEach _air;

// --- Ground QRF from every responding HQ
{
    private _hq = _y;
    private _isSrc = (_hq get "id") == _srcId;
    if !((_hq get "state") in (CQ_activeStates - ["Inbound"])) then { continue };

    private _d = (_hq get "pos") distance2D _pos;
    private _linked = _srcRadio
        && { alive (_hq get "radio") || { !(_hq get "buildDone") } }
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

if (_report isEqualTo []) then {
    ["QRF", format ["HQ #%1: nobody available to respond%2", _srcId, ["", " (radio down)"] select !_srcRadio]] call CQ_fnc_announce;
} else {
    ["QRF dispatched", (_report joinString ", ") + (["", ". Radio down: no help from other HQs"] select !_srcRadio)] call CQ_fnc_announce;
};
