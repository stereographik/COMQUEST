/*
    CQ_fnc_playerSetup  (client)
    Runs at join (initPlayerLocal) and after each respawn (onPlayerRespawn).
*/
if (!hasInterface) exitWith {};

// Role traits (setUnitTrait is local, so it runs here)
if (typeOf player in CQ_engineerClasses) then {
    player setUnitTrait ["engineer", true];
    player setUnitTrait ["explosiveSpecialist", true];
};

// Every preset carries binoculars and a GPS (class loadouts get them in CQ_fnc_setClass)
if (isNil "CQ_savedLoadout") then { call CQ_fnc_basicKit };

// adrenalineSurge: a downed medic may get back up on his own (one watcher per life)
[] spawn CQ_fnc_adrenalineSurge;

// Pilot seats
player addEventHandler ["GetInMan", {
    params ["_unit", "", "_veh"];
    [_unit, _veh] call CQ_fnc_pilotGuard;
}];
player addEventHandler ["SeatSwitchedMan", {
    params ["_unit", "", "_veh"];
    [_unit, _veh] call CQ_fnc_pilotGuard;
}];

// Supply crates: load into / unload from any vehicle (re-added on every respawn)
player addAction ["<t color='#7FF2FF'>Load supply crate into vehicle</t>",
    { [ "load", cursorObject, player ] remoteExec ["CQ_fnc_crateCargo", 2] }, nil, 5, true, true, "",
    "(cursorObject getVariable ['CQ_crate', false]) && { _this distance cursorObject < 4 } && { vehicle _this == _this }"];
player addAction ["<t color='#7FF2FF'>Unload supply crate</t>",
    { private _v = [cursorObject, vehicle player] select (vehicle player != player); [ "unload", _v, player ] remoteExec ["CQ_fnc_crateCargo", 2] }, nil, 5, true, true, "",
    "private _v = [cursorObject, vehicle _this] select (vehicle _this != _this); count (_v getVariable ['CQ_crates', []]) > 0 && { _this distance _v < 8 }"];

// Loadout zones: auto-fill / empty the inventory of the vehicle you sit in or look at
private _zoneVeh = "private _v = [cursorObject, vehicle _this] select (vehicle _this != _this); !isNull _v && { _v isKindOf 'AllVehicles' } && { !(_v isKindOf 'CAManBase') } && { _this distance _v < 10 } && { speed _v < 3 } && { (missionNamespace getVariable ['CQ_loadZones', []]) findIf { _v distance2D _x < CQ_loadZoneRadius } > -1 }";
player addAction ["<t color='#FFD27F'>Auto-fill vehicle (squad resupply)</t>",
    { private _v = [cursorObject, vehicle player] select (vehicle player != player); ["fill", _v, player] remoteExec ["CQ_fnc_vehAutoFill", 2] }, nil, 4.9, true, true, "", _zoneVeh];
player addAction ["<t color='#FFD27F'>Empty vehicle inventory</t>",
    { private _v = [cursorObject, vehicle player] select (vehicle player != player); ["clear", _v, player] remoteExec ["CQ_fnc_vehAutoFill", 2] }, nil, 0.5, false, true, "", _zoneVeh];

// Hub menu (squads, class, stats, shop, debug): U key + one scroll menu entry (re-added on every respawn)
player addAction ["<t color='#7FF2FF'>Menu (U)</t>", { [] spawn CQ_fnc_menuUi }, nil, 0.6, false, true, "", "_this == _target"];
if (isNil "CQ_squadKeyBound") then {
    CQ_squadKeyBound = true;
    [] spawn {
        waitUntil { sleep 0.5; !isNull (findDisplay 46) };
        (findDisplay 46) displayAddEventHandler ["KeyDown", {
            params ["", "_key", "_shift", "_ctrl", "_alt"];
            if (_key == 22 && { !_shift && !_ctrl && !_alt }) then { [] spawn CQ_fnc_menuUi; true } else { false };   // 22 = U: the hub menu
        }];
    };
};

// Debug panel: F3 (also in the U menu), for debug missions, the host and logged-in admins
if (isNil "CQ_debugKeyBound") then {
    CQ_debugKeyBound = true;
    [] spawn {
        waitUntil { sleep 0.5; !isNull (findDisplay 46) };
        (findDisplay 46) displayAddEventHandler ["KeyDown", {
            params ["", "_key"];
            if (_key == 61 && { CQ_debug || { isServer } || { (call BIS_fnc_admin) > 0 } }) then { [] spawn CQ_fnc_debugUi; true } else { false };   // 61 = F3
        }];
    };
};

// Once per client: arsenal action + save the loadout when the arsenal closes
if (isNil "CQ_arsenalReady") then {
    CQ_arsenalReady = true;

    [missionNamespace, "arsenalClosed", {
        CQ_savedLoadout = getUnitLoadout player;
        hint "Loadout saved: you will respawn with it.";
    }] call BIS_fnc_addScriptedEventHandler;

    [] spawn {
        waitUntil { sleep 0.5; !isNil "CQ_arsenalBoxes" };
        {
            _x addAction [
                format ["<t color='#7FF2FF'>Arsenal (%1 equipment)</t>", _x getVariable ["CQ_squadBox", ""]],
                { ["Open", true] spawn BIS_fnc_arsenal },
                nil, 6, true, true, "", "true", 6
            ];
        } forEach CQ_arsenalBoxes;
        waitUntil { sleep 0.5; !isNil "CQ_shopTerminal" };
        CQ_shopTerminal addAction ["<t color='#FFD27F'>Vehicle shop (squad points)</t>", { [] spawn CQ_fnc_shopUi }, nil, 6, true, true, "", "true", CQ_shopRange];
    };
};
