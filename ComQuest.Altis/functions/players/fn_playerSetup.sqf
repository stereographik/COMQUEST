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
