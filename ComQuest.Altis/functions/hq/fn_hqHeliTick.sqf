/*
    CQ_fnc_hqHeliTick  (server, from CQ_fnc_hqTick)
    QRF helicopter: parked -> hunting (CQ_heliHuntTime) -> returning -> landed back on the pad.
*/
params ["_hq"];

private _state = _hq get "heliState";
if (_state in ["none", "lost", "parked"]) exitWith {};

private _heli = _hq get "heli";
private _hg = _hq get "heliGrp";
private _id = _hq get "id";

if (!alive _heli || { !alive driver _heli }) exitWith {
    _hq set ["heliState", "lost"];
    ["Enemy helicopter down", format ["HQ #%1 has lost its QRF helicopter", _id]] call CQ_fnc_announce;
};

private _pad = _hq get "pad";
private _padPos = if (isNull _pad) then { _hq get "pos" } else { getPosATL _pad };

switch (_state) do {
    case "hunting": {
        if (time > (_hq get "heliUntil")) then {
            [_hg] call CQ_fnc_clearWaypoints;
            _hg setBehaviour "AWARE";
            _heli doMove _padPos;
            _hq set ["heliState", "returning"];
            ["HQ #%1: QRF helicopter returning to base", [_id]] call CQ_fnc_log;
        };
    };
    case "returning": {
        if (_heli distance2D _padPos > 200) then {
            _heli doMove _padPos;
        } else {
            if (isTouchingGround _heli) then {
                _heli engineOn false;
                _hg setBehaviour "SAFE";
                _hq set ["heliState", "parked"];
                ["HQ #%1: QRF helicopter landed, ready again", [_id]] call CQ_fnc_log;
            } else {
                _heli land "LAND";
            };
        };
    };
};
