/*
    CQ_fnc_magMapClient  (client, spawned once from initPlayerLocal)
    What MAGPIE gives every player, live:
      on the main map:
      - her drones (blue UAV icon + callsign), our data link, the enemy radio network
      - every enemy one of her drones has in sight (CQ_magVisible, refreshed by the server every
        CQ_magDetectEvery s): his own map icon (man, car, tank...) in chart red (CQ_echoColor),
        no text, at his live position and heading. Out of sight = the icon goes.
      - under them, the range map (CQ_fnc_rangeMapClient): the ground those enemies can fire on.
      - friendlies through the data link (CQ_fnc_bftClient, CQ_bft)
      - help calls (CQ_fnc_helpCall): red medic cross, white border, callsign
      on the GPS panel (CQ_gpsOverlay): the same enemy icons, range map and friendlies.
*/
if (!hasInterface) exitWith {};
CQ_magIconOf = {
    private _i = getText (configOf _this >> "icon");
    private _p = getText (configFile >> "CfgVehicleIcons" >> _i);
    [_p, _i] select (_p == "")
};
// range map + live enemy icons, shared by the main map and the GPS panel
CQ_magDrawEnemies = {
    params ["_map"];
    CQ_echoColor params ["_cr", "_cg", "_cb"];
    // range map (CQ_fnc_rangeMapClient) under the icons: cells inside the map control only,
    // redder where more enemies can fire, darker inside their fire cones
    if (CQ_rangeMap) then {
        ctrlPosition _map params ["_cx", "_cy", "_cw", "_ch"];
        private _tl = _map ctrlMapScreenToWorld [_cx, _cy];
        private _br = _map ctrlMapScreenToWorld [_cx + _cw, _cy + _ch];
        private _h = CQ_rangeCell / 2;
        {
            _y params ["_x0", "_y0", "_cnt", "_cone"];
            if (_x0 + _h < (_tl select 0) || { _x0 - _h > (_br select 0) } || { _y0 - _h > (_tl select 1) } || { _y0 + _h < (_br select 1) }) then { continue };
            private _a = (CQ_rangeAlpha select 0) + (CQ_rangeAlpha select 1) * ((_cnt min 4) - 1) + ([0, CQ_rangeAlpha select 2] select (_cone > 0));
            _map drawRectangle [[_x0, _y0], _h, _h, 0, [_cr, _cg, _cb, _a min 0.6], "#(rgb,8,8,3)color(1,1,1,1)"];
        } forEach (missionNamespace getVariable ["CQ_rangeAgg", createHashMap]);
    };
    // enemies in sight: one icon per vehicle (crew share it), regular size, no text
    private _sz = CQ_enemyIconPx * CQ_mapIconScale;
    private _vs = (missionNamespace getVariable ["CQ_magVisible", []]) apply { vehicle _x };
    {
        if (alive _x) then {
            _map drawIcon [_x call CQ_magIconOf, [_cr, _cg, _cb, 1], getPosASLVisual _x, _sz, _sz, getDirVisual _x, "", 0];
        };
    } forEach (_vs arrayIntersect _vs);
};
// help calls (CQ_fnc_helpCall): red medic cross with a thin white border, every player
CQ_helpDraw = {
    params ["_map"];
    private _sz = CQ_helpIconPx * CQ_mapIconScale;
    private _tex = "\A3\ui_f\data\map\vehicleicons\pictureHeal_ca.paa";
    {
        _x params ["", "_p", "", "_cs"];
        _map drawIcon [_tex, [1, 1, 1, 1], _p, _sz + 4, _sz + 4, 0, "", 0];          // white border
        _map drawIcon [_tex, [0.85, 0.1, 0.1, 1], _p, _sz, _sz, 0, _cs, 1, 0.03, "PuristaMedium", "right"];
    } forEach (missionNamespace getVariable ["CQ_helpCalls", []]);
};
[] spawn {
    disableSerialization;
    waitUntil { sleep 0.5; !isNull ((findDisplay 12) displayCtrl 51) };
    ((findDisplay 12) displayCtrl 51) ctrlAddEventHandler ["Draw", {
        params ["_map"];
        _map call CQ_magDrawEnemies;
        if (CQ_bft) then { _map call CQ_bftDraw };
        _map call CQ_helpDraw;
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
            _map drawIcon ["\a3\ui_f\data\igui\cfg\simpletasks\types\radio_ca.paa", [0.25, 0.55, 1, 1], _rp, 22 * CQ_mapIconScale, 22 * CQ_mapIconScale, 0, "RELAY", 1, 0.035, "PuristaMedium", "right"];
        } forEach _nRelays;
        private _rvh = missionNamespace getVariable ["CQ_linkRelayVeh", objNull];
        if (alive _rvh) then {
            _map drawIcon ["\a3\ui_f\data\igui\cfg\simpletasks\types\radio_ca.paa", [0.25, 0.55, 1, 1], getPosASLVisual _rvh, 22 * CQ_mapIconScale, 22 * CQ_mapIconScale, 0, "RELAY VEHICLE", 1, 0.035, "PuristaMedium", "right"];
        };
        {
            _x params ["_a", "_b", "_ok"];
            _map drawLine [_a, _b, [[0.45, 0.45, 0.42, 0.8], CQ_echoColor + [0.9]] select _ok];
        } forEach _nLinks;
        // trunk: a stub from each root HQ toward the carrier (its position stays unknown)
        { _x params ["_a", "_b"]; _map drawLine [_a, _a getPos [CQ_netTrunkStub, _a getDir _b], CQ_echoColor + [0.9]] } forEach _nTrunk;
        {
            if (alive _x && { !(_x isKindOf "UAV_01_base_F") || { _x getVariable ["CQ_linked", false] } }) then {   // a Darter shows only while linked to the base
                private _sz = ([26, 13] select (_x isKindOf "UAV_01_base_F")) * CQ_mapIconScale;   // Darters: half the others
                _map drawIcon [_x call CQ_magIconOf, [0.25, 0.55, 1, 1], getPosASLVisual _x, _sz, _sz, getDirVisual _x,
                    _x getVariable ["CQ_magName", ""], 1, 0.035, "PuristaMedium", "right"];
            };
        } forEach (missionNamespace getVariable ["CQ_magVehs", []]);
    }];
};
// GPS panel (RscCustomInfoMiniMap, map idc 101): the game rebuilds it every time the panel opens,
// so look for it every second and hook each new one
if (CQ_gpsOverlay) then {
    [] spawn {
        disableSerialization;
        while { true } do {
            private _gps = (uiNamespace getVariable ["RscCustomInfoMiniMap", displayNull]) displayCtrl 101;
            if (!isNull _gps && { !(_gps getVariable ["CQ_hooked", false]) }) then {
                _gps setVariable ["CQ_hooked", true];
                _gps ctrlAddEventHandler ["Draw", { (_this select 0) call CQ_magDrawEnemies; if (CQ_bft) then { (_this select 0) call CQ_bftDraw }; (_this select 0) call CQ_helpDraw }];
            };
            sleep 1;
        };
    };
};
