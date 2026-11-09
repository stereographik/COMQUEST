/*
    CQ_fnc_squadInvite  (client, remoteExec'd by the server on the invited player)
    [_leaderName, _squadName, _leader] call CQ_fnc_squadInvite;
    Modal window: "<leader> invites you to join <squad>"  ACCEPT / DECLINE.
    Closes itself (declined) after CQ_inviteTimeout seconds. The answer goes back to the
    server (CQ_fnc_squadCmd "inviteReply").
*/
params ["_lname", "_sname", "_leader"];
if (!hasInterface) exitWith {};
_this spawn {
    params ["_lname", "_sname", "_leader"];
    disableSerialization;
    // close a previous invite window if any
    private _prev = uiNamespace getVariable ["CQ_invDisplay", displayNull];
    if (!isNull _prev) then { _prev closeDisplay 2 };
    waitUntil { !isNull findDisplay 46 };

    // open on top of whatever is shown (game, or the U menu)
    private _parent = findDisplay 46;
    private _top = uiNamespace getVariable ["CQ_sqDisplay", displayNull];
    if (!isNull _top) then { _parent = _top };
    private _d = _parent createDisplay "RscDisplayEmpty";
    uiNamespace setVariable ["CQ_invDisplay", _d];
    uiNamespace setVariable ["CQ_invAnswer", -1];
    uiNamespace setVariable ["CQ_invLeader", _leader];

    private _pw = pixelW; private _ph = pixelH;
    private _W = 420; private _H = 150;
    private _x0 = safezoneX + (safezoneW - _W * _pw) / 2;
    private _y0 = safezoneY + (safezoneH - _H * _ph) / 2;
    private _mk = {
        params ["_cls", "_rx", "_ry", "_rw", "_rh", ["_txt", ""]];
        private _c = _d ctrlCreate [_cls, -1];
        _c ctrlSetPosition [_x0 + _rx * _pw, _y0 + _ry * _ph, _rw * _pw, _rh * _ph];
        if (_txt != "") then { _c ctrlSetText _txt };
        _c ctrlCommit 0;
        _c
    };
    (["RscText", 0, 0, _W, _H] call _mk) ctrlSetBackgroundColor [0.06, 0.06, 0.06, 0.95];
    (["RscText", 0, 0, 3, _H] call _mk) ctrlSetBackgroundColor [1, 1, 1, 0.9];
    private _title = ["RscText", 16, 10, _W - 32, 22, "SQUAD INVITE"] call _mk;
    _title ctrlSetFont "PuristaMedium";
    _title ctrlSetFontHeight (16 * _ph);
    _title ctrlSetTextColor [0.7, 0.7, 0.7, 1];
    private _msg = ["RscStructuredText", 14, 38, _W - 28, 50] call _mk;
    _msg ctrlSetStructuredText parseText format [
        "<t font='PuristaLight' size='1.1' color='#ffffff'>%1</t><t font='PuristaLight' size='1.1' color='#a0a0a0'> invites you to join </t><t font='PuristaSemibold' size='1.1' color='#ffffff'>%2</t>", _lname, _sname];
    private _timer = ["RscText", 16, _H - 40, 150, 26] call _mk;
    _timer ctrlSetFont "PuristaLight";
    _timer ctrlSetTextColor [0.55, 0.55, 0.55, 1];
    private _bNo = ["RscButton", _W - 266, _H - 44, 120, 32, "DECLINE"] call _mk;
    private _bYes = ["RscButton", _W - 136, _H - 44, 120, 32, "ACCEPT"] call _mk;
    _bYes ctrlSetBackgroundColor [0.85, 0.85, 0.85, 1];
    _bYes ctrlSetTextColor [0, 0, 0, 1];
    _bNo ctrlSetBackgroundColor [0.2, 0.2, 0.2, 1];
    _bYes ctrlAddEventHandler ["ButtonClick", { uiNamespace setVariable ["CQ_invAnswer", 1]; (uiNamespace getVariable ["CQ_invDisplay", displayNull]) closeDisplay 1 }];
    _bNo ctrlAddEventHandler ["ButtonClick", { uiNamespace setVariable ["CQ_invAnswer", 0]; (uiNamespace getVariable ["CQ_invDisplay", displayNull]) closeDisplay 2 }];
    playSound "Hint";

    private _end = time + CQ_inviteTimeout;
    while { !isNull _d && { time < _end } } do {
        _timer ctrlSetText format ["expires in %1 s", ceil (_end - time)];
        sleep 0.25;
    };
    if (!isNull _d) then { _d closeDisplay 2 };
    private _ok = (uiNamespace getVariable ["CQ_invAnswer", -1]) == 1;
    ["inviteReply", player, _leader, _ok] remoteExec ["CQ_fnc_squadCmd", 2];
    uiNamespace setVariable ["CQ_invDisplay", displayNull];
};
