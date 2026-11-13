/*
    CQ_fnc_hostageCarry
    ["carry", _hostage] call CQ_fnc_hostageCarry;        (client, the carrier) pick him up
    ["drop"] call CQ_fnc_hostageCarry;                   (client, the carrier) put him down
    ["load", _vehicle] call CQ_fnc_hostageCarry;         (client, the carrier) into a vehicle
    ["srvLoad", [_hostage, _vehicle]] remoteExec [..., 2] (server: he is local there)
    The technician is badly hurt and can't walk: after the firmware download he lies on the
    ground and a player carries him on his shoulder (no weapon in hand, slow), puts him down to
    fight, or loads him into any vehicle with a free seat, the extraction helicopter included.
    The carrier killed, downed or getting into a vehicle drops him.
*/
params ["_mode", ["_arg", objNull]];
private _carriedAnim = "AinjPfalMstpSnonWnonDf_carried_dead";
private _lyingAnim = "AinjPpneMstpSnonWnonDnon";

switch (_mode) do {
    case "carry": {
        private _h = _arg;
        if (!alive _h || { !isNull attachedTo _h } || { vehicle _h != _h } || { !isNil { player getVariable "CQ_hstCarrying" } }) exitWith {};
        player setVariable ["CQ_hstCarrying", _h];
        _h setVariable ["CQ_hstCarrier", player, true];
        player action ["SwitchWeapon", player, player, 299];   // weapon on the back
        player playMoveNow "AcinPknlMstpSnonWnonDnon_AcinPercMrunSnonWnonDnon";
        _h attachTo [player, [0.4, -0.1, -1.25], "LeftShoulder"];
        [_h, 194] remoteExec ["setDir", 0];
        [_h, _carriedAnim] remoteExec ["switchMove", 0];
        private _a1 = player addAction ["<t color='#918C3B'>Put the technician down</t>", { ["drop"] call CQ_fnc_hostageCarry }, nil, 6, false, true];
        private _a2 = player addAction ["<t color='#918C3B'>Load the technician into the vehicle</t>",
            { ["load", cursorObject] call CQ_fnc_hostageCarry }, nil, 7, true, true, "",
            "!isNull cursorObject && { cursorObject isKindOf 'AllVehicles' } && { !(cursorObject isKindOf 'CAManBase') } && { alive cursorObject } && { player distance cursorObject < 8 } && { (cursorObject emptyPositions 'cargo') > 0 }"];
        player setVariable ["CQ_hstActs", [_a1, _a2]];
        hint "Carrying the technician. Scroll: put him down, or look at a vehicle to load him.";
        [_h] spawn {
            params ["_h"];
            waitUntil { sleep 0.5;
                !alive player || { !alive _h } || { lifeState player == "INCAPACITATED" } || { vehicle player != player } || { attachedTo _h != player }
            };
            if ((player getVariable ["CQ_hstCarrying", objNull]) == _h) then { ["drop"] call CQ_fnc_hostageCarry };
        };
    };
    case "drop": {
        private _h = player getVariable ["CQ_hstCarrying", objNull];
        player setVariable ["CQ_hstCarrying", nil];
        { player removeAction _x } forEach (player getVariable ["CQ_hstActs", []]);
        player setVariable ["CQ_hstActs", nil];
        if (alive player && { vehicle player == player }) then { player switchMove "" };
        if (isNull _h) exitWith {};
        _h setVariable ["CQ_hstCarrier", objNull, true];
        if (attachedTo _h == player) then {
            detach _h;
            _h setPosATL ((getPosATL player) getPos [1, getDir player]);
        };
        if (alive _h && { vehicle _h == _h }) then { [_h, _lyingAnim] remoteExec ["switchMove", 0] };
    };
    case "load": {
        private _v = _arg;
        private _h = player getVariable ["CQ_hstCarrying", objNull];
        if (isNull _h || { isNull _v }) exitWith {};
        ["drop"] call CQ_fnc_hostageCarry;
        ["srvLoad", [_h, _v]] remoteExec ["CQ_fnc_hostageCarry", 2];
    };
    case "srvLoad": {
        if (!isServer) exitWith {};
        _arg params ["_h", "_v"];
        if (!alive _h || { !alive _v }) exitWith {};
        detach _h;
        [_h, ""] remoteExec ["switchMove", 0];
        _h assignAsCargo _v;
        _h moveInCargo _v;
        if (vehicle _h != _v) then { [_h, _lyingAnim] remoteExec ["switchMove", 0] };   // no seat after all
    };
};
