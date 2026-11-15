/*
    CQ_fnc_helpCall
    A squad leader calls for help (action "Call for help", CQ_fnc_playerSetup):
      - a white flare is fired straight up over his position, tinted blue on every client
        (vanilla has no blue flare: blue light point + blue glow riding the flare)
      - COMHAT tells every player who needs help and where (card + chat)
      - a medic marker (red cross, thin white border) shows on every player's map and GPS at
        once, gone after CQ_helpLife s or when his leader cancels it ("Cancel help call")
    One active call per squad: a new call moves the marker.
    Modes:
      ["call",   [unit]]          server
      ["cancel", [unit]]          server
      ["fx",     [flare]]         every client (blue tint)
      ["msg",    [text]]          every client (COMHAT)
    CQ_helpCalls (public): [[groupNetId, pos, startTime, callsign], ...]
    CQ_helpDraw (client): draws them, called by CQ_fnc_magMapClient on the map and the GPS.
*/
params [["_mode", ""], ["_args", []]];
switch (_mode) do {
    case "call": {
        if (!isServer) exitWith {};
        _args params [["_u", objNull]];
        if (!alive _u || { leader group _u != _u }) exitWith {};
        private _g = group _u;
        private _id = netId _g;
        private _pos = getPosATL _u;
        private _cs = groupId _g;
        if (isNil "CQ_helpCalls") then { CQ_helpCalls = [] };
        CQ_helpCalls = (CQ_helpCalls select { (_x select 0) != _id }) + [[_id, _pos, serverTime, _cs]];
        publicVariable "CQ_helpCalls";
        // flare straight up from the squad
        private _f = CQ_helpFlare createVehicle (_pos vectorAdd [0, 0, 2]);
        _f setPosATL (_pos vectorAdd [0, 0, 2]);
        _f setVelocity [0, 0, CQ_helpFlareSpeed];
        ["fx", [_f]] remoteExec ["CQ_fnc_helpCall", 0];
        ["msg", [format ["%1 requests help at grid %2. Medic marker on your map.", _cs, mapGridPosition _pos]]] remoteExec ["CQ_fnc_helpCall", 0];
        ["Help call: %1 at %2", [_cs, mapGridPosition _pos]] call CQ_fnc_log;
        // auto removal (only this call: a newer call of the same squad has another start time)
        private _t0 = (CQ_helpCalls select (count CQ_helpCalls - 1)) select 2;
        [_id, _t0] spawn {
            params ["_id", "_t0"];
            sleep CQ_helpLife;
            private _n = count CQ_helpCalls;
            CQ_helpCalls = CQ_helpCalls select { !((_x select 0) == _id && { (_x select 2) == _t0 }) };
            if (count CQ_helpCalls != _n) then { publicVariable "CQ_helpCalls" };
        };
    };
    case "cancel": {
        if (!isServer) exitWith {};
        _args params [["_u", objNull]];
        if (isNull _u || { leader group _u != _u } || { isNil "CQ_helpCalls" }) exitWith {};
        private _id = netId group _u;
        CQ_helpCalls = CQ_helpCalls select { (_x select 0) != _id };
        publicVariable "CQ_helpCalls";
        ["msg", [format ["%1: help call cancelled.", groupId group _u]]] remoteExec ["CQ_fnc_helpCall", 0];
    };
    case "fx": {
        if (!hasInterface) exitWith {};
        _args params [["_f", objNull]];
        if (isNull _f) exitWith {};
        _f spawn {
            private _l = "#lightpoint" createVehicleLocal (getPosATL _this);
            _l lightAttachObject [_this, [0, 0, 0]];
            _l setLightColor [0.15, 0.35, 1];
            _l setLightAmbient [0.05, 0.15, 0.6];
            _l setLightBrightness CQ_helpLightBright;
            _l setLightAttenuation [2, 4, 4, 0, 9, 10];
            _l setLightDayLight true;
            private _t = time + 90;
            waitUntil { sleep 0.25; isNull _this || { time > _t } };
            deleteVehicle _l;
        };
    };
    case "msg": {
        if (!hasInterface) exitWith {};
        _args params [["_txt", ""]];
        playSound "CQ_radioIn";
        ["COMHAT", _txt] call CQ_fnc_storyUi;
        systemChat format ["[COMHAT] %1", _txt];
    };
};
