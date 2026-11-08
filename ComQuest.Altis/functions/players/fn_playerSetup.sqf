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
player addAction ["<t color='#C8E07A'>Load supply crate into vehicle</t>",
    { [ "load", cursorObject, player ] remoteExec ["CQ_fnc_crateCargo", 2] }, nil, 5, true, true, "",
    "(cursorObject getVariable ['CQ_crate', false]) && { _this distance cursorObject < 4 } && { vehicle _this == _this }"];
player addAction ["<t color='#C8E07A'>Unload supply crate</t>",
    { private _v = [cursorObject, vehicle player] select (vehicle player != player); [ "unload", _v, player ] remoteExec ["CQ_fnc_crateCargo", 2] }, nil, 5, true, true, "",
    "private _v = [cursorObject, vehicle _this] select (vehicle _this != _this); count (_v getVariable ['CQ_crates', []]) > 0 && { _this distance _v < 8 }"];

// Squad management (U) and leaderboard: scroll menu entries (re-added on every respawn) + U key
player addAction ["<t color='#9FD3FF'>Squad management (U)</t>", { ["squads"] spawn CQ_fnc_squadUi }, nil, 0.6, false, true, "", "true"];
player addAction ["<t color='#9FD3FF'>Leaderboard</t>", { ["board"] spawn CQ_fnc_squadUi }, nil, 0.59, false, true, "", "true"];
if (isNil "CQ_squadKeyBound") then {
    CQ_squadKeyBound = true;
    [] spawn {
        waitUntil { sleep 0.5; !isNull (findDisplay 46) };
        (findDisplay 46) displayAddEventHandler ["KeyDown", {
            params ["", "_key", "_shift", "_ctrl", "_alt"];
            if (_key == 22 && { !_shift && !_ctrl && !_alt }) then { ["squads"] spawn CQ_fnc_squadUi; true } else { false };   // 22 = U
        }];
    };
};

// Debug panel: F3 only (no scroll menu entry), debug missions only
if (CQ_debug) then {
    if (isNil "CQ_debugKeyBound") then {
        CQ_debugKeyBound = true;
        [] spawn {
            waitUntil { sleep 0.5; !isNull (findDisplay 46) };
            (findDisplay 46) displayAddEventHandler ["KeyDown", {
                params ["", "_key"];
                if (_key == 61) then { [] spawn CQ_fnc_debugUi; true } else { false };   // 61 = F3
            }];
        };
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
        waitUntil { sleep 0.5; !isNil "CQ_arsenalBox" };
        CQ_arsenalBox addAction [
            "<t color='#7FD4FF'>Arsenal</t>",
            { ["Open", true] spawn BIS_fnc_arsenal },
            nil, 6, true, true, "", "true", 6
        ];
    };
};
