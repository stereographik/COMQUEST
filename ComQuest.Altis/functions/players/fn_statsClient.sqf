/*
    CQ_fnc_statsClient  (client, spawned once from initPlayerLocal)
    Local statistics sent to the server every 30 s (CQ_fnc_statsAdd):
      shots fired, heals given (credited by the healed player's machine), distance on foot
      and in vehicles, time played (alive).
*/
if (!hasInterface) exitWith {};
CQ_stShots = 0;
private _last = objNull;
private _pos = getPosASL player;
private _foot = 0; private _veh = 0; private _time = 0;
private _sendT = time + 30;
while { true } do {
    sleep 2;
    if (player != _last) then {
        _last = player;
        _pos = getPosASL player;
        player addEventHandler ["Fired", { CQ_stShots = CQ_stShots + 1 }];
        // demolition charges: where each one goes off is sent to the server (objectives that need N charges, CQ_fnc_chargeHit)
        player addEventHandler ["Fired", {
            params ["_u", "", "", "", "_ammo", "", "_proj"];
            if (!(_ammo in CQ_engineerCharges) || { isNull _proj }) exitWith {};
            _proj setVariable ["CQ_by", _u];
            _proj addEventHandler ["Explode", {
                params ["_p", "_pos"];
                [ASLToAGL _pos, _p getVariable ["CQ_by", player]] remoteExec ["CQ_fnc_chargeHit", 2];
            }];
        }];
        player addEventHandler ["HandleHeal", {
            params ["_unit", "_healer"];
            if (!isNull _healer && { _healer != _unit } && { isPlayer _healer }) then {
                [_healer, [["heals", 1]]] remoteExec ["CQ_fnc_statsAdd", 2];
            };
            nil
        }];
    };
    if (alive player) then {
        _time = _time + 2;
        private _p = getPosASL player;
        private _d = _p distance2D _pos;
        _pos = _p;
        if (_d < 300) then {
            if (vehicle player == player) then { _foot = _foot + _d } else { _veh = _veh + _d };
        };
    };
    if (time > _sendT) then {
        _sendT = time + 30;
        private _pairs = [["timePlayed", _time], ["distFoot", round _foot], ["distVeh", round _veh], ["shots", CQ_stShots]];
        CQ_stShots = 0; _foot = 0; _veh = 0; _time = 0;
        [player, _pairs] remoteExec ["CQ_fnc_statsAdd", 2];
    };
};
