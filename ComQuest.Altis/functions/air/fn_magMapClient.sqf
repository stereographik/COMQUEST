/*
    CQ_fnc_magMapClient  (client, spawned once from initPlayerLocal)
    What MAGPIE gives every player on the map, live:
      - her drones (blue UAV icon + callsign), always
      - radar echoes of every enemy one of her drones has in sight (CQ_magVisible, refreshed by
        the server every CQ_magDetectEvery s), crisp circles of CQ_echoPx pixels whatever the
        zoom, chart red (CQ_echoColor):
          live    a filled circle at the enemy's live position while he is in sight
          trace   every CQ_magDetectEvery s an empty circle is left where he was, fading out
                  over CQ_echoLife s (shows the movement)
        Out of sight = the live circle goes, the last traces fade.
      - under them, the range map (CQ_fnc_rangeMapClient): the ground those enemies can fire on.
*/
if (!hasInterface) exitWith {};
// traces: a snapshot of the visible enemies' positions every detection pass, kept CQ_echoLife s
CQ_echoes = [];
[] spawn {
    while { true } do {
        private _now = time;
        CQ_echoes = CQ_echoes select { _now - (_x select 1) < CQ_echoLife };
        { if (alive _x) then { CQ_echoes pushBack [getPosASL _x, _now] } } forEach (missionNamespace getVariable ["CQ_magVisible", []]);
        sleep CQ_magDetectEvery;
    };
};
[] spawn {
    disableSerialization;
    waitUntil { sleep 0.5; !isNull ((findDisplay 12) displayCtrl 51) };
    ((findDisplay 12) displayCtrl 51) ctrlAddEventHandler ["Draw", {
        params ["_map"];
        private _icon = {
            private _i = getText (configOf _this >> "icon");
            private _p = getText (configFile >> "CfgVehicleIcons" >> _i);
            [_p, _i] select (_p == "")
        };
        // radar echoes: CQ_echoPx pixels across at any zoom (metres per screen pixel right now)
        private _r = (CQ_echoPx / 2) * ((_map ctrlMapScreenToWorld [0.5, 0.5]) distance2D (_map ctrlMapScreenToWorld [0.5 + pixelW, 0.5]));
        CQ_echoColor params ["_cr", "_cg", "_cb"];
        // range map (CQ_fnc_rangeMapClient) under the echoes: cells on screen only, redder where
        // more enemies can fire, darker inside their fire cones
        if (CQ_rangeMap) then {
            private _tl = _map ctrlMapScreenToWorld [safeZoneX, safeZoneY];
            private _br = _map ctrlMapScreenToWorld [safeZoneX + safeZoneW, safeZoneY + safeZoneH];
            private _h = CQ_rangeCell / 2;
            {
                _y params ["_x0", "_y0", "_cnt", "_cone"];
                if (_x0 < (_tl select 0) || { _x0 > (_br select 0) } || { _y0 > (_tl select 1) } || { _y0 < (_br select 1) }) then { continue };
                private _a = (CQ_rangeAlpha select 0) + (CQ_rangeAlpha select 1) * ((_cnt min 4) - 1) + ([0, CQ_rangeAlpha select 2] select (_cone > 0));
                _map drawRectangle [[_x0, _y0], _h, _h, 0, [_cr, _cg, _cb, _a min 0.6], "#(rgb,8,8,3)color(1,1,1,1)"];
            } forEach (missionNamespace getVariable ["CQ_rangeAgg", createHashMap]);
        };
        // nGD: the enemy radio network (CQ_fnc_netTick) and our MAGPIE coverage
        (missionNamespace getVariable ["CQ_netPub", []]) params [["_nNodes", []], ["_nLinks", []], ["_nTrunk", []], ["_nRelays", []], ["_nBase", 0]];
        // our data link (CQ_fnc_linkTick): every node's range (blue linked, grey cut off) and the links
        (missionNamespace getVariable ["CQ_linkPub", []]) params [["_lNodes", []], ["_lEdges", []]];
        {
            _x params ["_lp", "_lr", "_lok"];
            _map drawEllipse [_lp, _lr, _lr, 0, [[0.5, 0.5, 0.5, 0.25], [0.25, 0.55, 1, 0.35]] select _lok, ""];
        } forEach _lNodes;
        { _map drawLine [_x select 0, _x select 1, [0.25, 0.55, 1, 0.6]] } forEach _lEdges;
        {
            _x params ["_rp", "_rr"];
            _map drawIcon ["\a3\ui_f\data\igui\cfg\simpletasks\types\radio_ca.paa", [0.25, 0.55, 1, 1], _rp, 22, 22, 0, "RELAY", 1, 0.035, "PuristaMedium", "right"];
        } forEach _nRelays;
        private _rvh = missionNamespace getVariable ["CQ_linkRelayVeh", objNull];
        if (alive _rvh) then {
            _map drawIcon ["\a3\ui_f\data\igui\cfg\simpletasks\types\radio_ca.paa", [0.25, 0.55, 1, 1], getPosASLVisual _rvh, 22, 22, 0, "RELAY VEHICLE", 1, 0.035, "PuristaMedium", "right"];
        };
        {
            _x params ["_a", "_b", "_ok"];
            _map drawLine [_a, _b, [[0.45, 0.45, 0.42, 0.8], CQ_echoColor + [0.9]] select _ok];
        } forEach _nLinks;
        // trunk: a stub from each root HQ toward the carrier (its position stays unknown)
        { _x params ["_a", "_b"]; _map drawLine [_a, _a getPos [CQ_netTrunkStub, _a getDir _b], CQ_echoColor + [0.9]] } forEach _nTrunk;
        private _now = time;
        {
            _x params ["_p", "_t"];
            private _a = 1 - (_now - _t) / CQ_echoLife;
            if (_a > 0) then { _map drawEllipse [_p, _r, _r, 0, [_cr, _cg, _cb, _a], ""] };
        } forEach (missionNamespace getVariable ["CQ_echoes", []]);
        {
            if (alive _x) then { _map drawEllipse [getPosASLVisual _x, _r, _r, 0, [_cr, _cg, _cb, 1], "#(rgb,8,8,3)color(1,1,1,1)"] };
        } forEach (missionNamespace getVariable ["CQ_magVisible", []]);
        {
            if (alive _x && { !(_x isKindOf "UAV_01_base_F") || { _x getVariable ["CQ_linked", false] } }) then {   // a Darter shows only while linked to the base
                private _sz = [26, 13] select (_x isKindOf "UAV_01_base_F");   // Darters: half size
                _map drawIcon [_x call _icon, [0.25, 0.55, 1, 1], getPosASLVisual _x, _sz, _sz, getDirVisual _x,
                    format ["MAGPIE %1", _x getVariable ["CQ_magName", ""]], 1, 0.035, "PuristaMedium", "right"];
            };
        } forEach (missionNamespace getVariable ["CQ_magVehs", []]);
    }];
};
