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
if (isNil "CQ_savedLoadout") then { ["Rifleman"] call CQ_fnc_classKit };

// Player feed: what last hit him (the enemy's class, or its vehicle), told to everyone when he
// goes down (CQ_fnc_adrenalineSurge) or dies outright (initServer.sqf)
player addEventHandler ["HandleDamage", {
    params ["_u", "", "_dmg", "_src", "", "", "_inst"];
    private _w = [_inst, _src] select (isNull _inst);
    if (!isNull _w && { _w != _u } && { _dmg > 0.05 }) then {
        private _o = [vehicle _w, _w] select (vehicle _w == _w);
        private _nm = getText (configOf _o >> "displayName");
        if (_nm == "") then { _nm = typeOf _o };
        if (_nm != (_u getVariable ["CQ_lastHit", ""])) then { _u setVariable ["CQ_lastHit", _nm, true] };
        // teamkill watch (CQ_fnc_conduct): who of ours last hurt him, for a death after bleeding out
        private _pw = [effectiveCommander _w, _w] select (_w isKindOf "CAManBase");
        if (isPlayer _pw && { _pw != _u }) then { _u setVariable ["CQ_lastHitBy", [_pw, serverTime, vehicle _w != _w || { !(_w isKindOf "CAManBase") }], true] };
    };
    nil
}];

// Weapons-safe perimeter around the base (CQ_fnc_safeZoneFired)
player addEventHandler ["FiredMan", { _this call CQ_fnc_safeZoneFired }];

// adrenalineSurge: a downed medic may get back up on his own (one watcher per life)
[] spawn CQ_fnc_adrenalineSurge;

// Pilot seats; no vehicle before the server rules are accepted, or while locked out (CQ_fnc_conduct)
player addEventHandler ["GetInMan", {
    params ["_unit", "", "_veh"];
    if !(["can"] call CQ_fnc_conduct) exitWith { moveOut _unit };
    [_unit, _veh] call CQ_fnc_pilotGuard;
}];
player addEventHandler ["SeatSwitchedMan", {
    params ["_unit", "", "_veh"];
    [_unit, _veh] call CQ_fnc_pilotGuard;
}];

// Supply crates: load into / unload from any vehicle (re-added on every respawn)
player addAction ["<t color='#918C3B'>Load supply crate into vehicle</t>",
    { [ "load", cursorObject, player ] remoteExec ["CQ_fnc_crateCargo", 2] }, nil, 5, true, true, "",
    "(cursorObject getVariable ['CQ_crate', false]) && { _this distance cursorObject < 4 } && { vehicle _this == _this }"];
player addAction ["<t color='#918C3B'>Unload supply crate</t>",
    { private _v = [cursorObject, vehicle player] select (vehicle player != player); [ "unload", _v, player ] remoteExec ["CQ_fnc_crateCargo", 2] }, nil, 5, true, true, "",
    "private _v = [cursorObject, vehicle _this] select (vehicle _this != _this); count (_v getVariable ['CQ_crates', []]) > 0 && { _this distance _v < 8 }"];

// Engineers: short sandbag walls in the field (CQ_fnc_sandbag), recalled from the base
player addAction ["<t color='#918C3B'>Build a sandbag wall</t>", { ["place"] spawn CQ_fnc_sandbag }, nil, 1.2, false, true, "",
    "_this getUnitTrait 'engineer' && { vehicle _this == _this } && { isNil 'CQ_sbGhost' } && { _this distance2D CQ_basePos > CQ_baseRadius } && { (missionNamespace getVariable ['CQ_sb_' + getPlayerUID _this, 0]) < CQ_sbMax }"];
player addAction ["<t color='#918C3B'>Recall my sandbag walls</t>", { ["recall", [player]] remoteExec ["CQ_fnc_sandbag", 2] }, nil, 1.1, false, true, "",
    "_this distance2D CQ_basePos < CQ_baseRadius && { (missionNamespace getVariable ['CQ_sb_' + getPlayerUID _this, 0]) > 0 }"];

// Loadout zones: auto-fill / empty the inventory of the vehicle you sit in or look at
private _zoneVeh = "private _v = [cursorObject, vehicle _this] select (vehicle _this != _this); !isNull _v && { _v isKindOf 'AllVehicles' } && { !(_v isKindOf 'CAManBase') } && { _this distance _v < 10 } && { speed _v < 3 } && { [_v] call CQ_fnc_vehFillSpot }";
player addAction ["<t color='#918C3B'>Autofill for my squad</t>",
    { private _v = [cursorObject, vehicle player] select (vehicle player != player); ["fill", _v, player] remoteExec ["CQ_fnc_vehAutoFill", 2] }, nil, 4.9, true, true, "", _zoneVeh];
player addAction ["<t color='#918C3B'>Empty vehicle cargo</t>",
    { private _v = [cursorObject, vehicle player] select (vehicle player != player); ["clear", _v, player] remoteExec ["CQ_fnc_vehAutoFill", 2] }, nil, 0.5, false, true, "", _zoneVeh];

// Vehicle depot: give back the depot vehicle you sit in or look at, next to a depot
player addAction ["<t color='#918C3B'>Return vehicle to the depot</t>",
    { private _v = [cursorObject, vehicle player] select (vehicle player != player); [player, _v] remoteExec ["CQ_fnc_depotReturn", 2] }, nil, 4.8, false, true, "",
    "private _v = [cursorObject, vehicle _this] select (vehicle _this != _this); _v in (missionNamespace getVariable ['CQ_depotVehs', []]) && { alive _v } && { _this distance _v < 10 } && { speed _v < 3 } && { (missionNamespace getVariable ['CQ_depots', []]) findIf { _v distance2D (_x select 0) < CQ_depotReturnRange || { _v distance2D (_x select 1) < CQ_depotReturnRange } } > -1 }"];

// Squad respawn vehicle (CQ_fnc_rspVeh): the leader locks / unlocks the vehicle he sits in or
// looks at; members at the base teleport into it (one credit per teleport)
private _rspTgt = "private _v = [cursorObject, vehicle _this] select (vehicle _this != _this); !isNull _v && { alive _v } && { _v isKindOf 'LandVehicle' || { _v isKindOf 'Air' } } && { _this distance _v < 10 } && { leader group _this == _this } && { !(group _this getVariable ['CQ_solo', false]) }";
player addAction ["<t color='#918C3B'>Lock as squad respawn vehicle</t>",
    { private _v = [cursorObject, vehicle player] select (vehicle player != player); ["lock", player, _v] remoteExec ["CQ_fnc_rspVeh", 2] }, nil, 1, false, true, "",
    _rspTgt + " && { getNumber (configOf _v >> 'side') != 0 } && { (group _this getVariable ['CQ_rspVeh', objNull]) != _v } && { (_v getVariable ['CQ_rspLeft', CQ_rspCredits]) > 0 }"];
player addAction ["<t color='#BA392C'>Unlock squad respawn vehicle</t>",
    { ["unlock", player] remoteExec ["CQ_fnc_rspVeh", 2] }, nil, 0.9, false, true, "",
    _rspTgt + " && { (group _this getVariable ['CQ_rspVeh', objNull]) == _v }"];
player addAction ["<t color='#918C3B'>Teleport to the squad respawn vehicle</t>",
    { ["use", player] remoteExec ["CQ_fnc_rspVeh", 2] }, nil, 5.5, true, true, "",
    "vehicle _this == _this && { _this distance2D CQ_musterPos < CQ_rspBaseRange } && { private _rv = group _this getVariable ['CQ_rspVeh', objNull]; alive _rv && { (_rv getVariable ['CQ_rspLeft', 0]) > 0 } }"];

// Radio tower hack: done on the field terminal at the tower's foot (CQ_fnc_hqBuild). Near a
// tower that can be hacked, a short reminder of who can do it
if (isNil "CQ_hackHintLoop") then {
    CQ_hackHintLoop = true;
    [] spawn {
        private _last = objNull;
        while { true } do {
            sleep 2;
            private _t = (nearestObjects [player, ["Land_TTowerBig_2_F"], 30]) select { _x getVariable ["CQ_hackable", false] };
            if (_t isEqualTo [] || { (_t select 0) == _last }) then { continue };
            _last = _t select 0;
            hint ([format ["Enemy radio tower: hack it on the field terminal at its foot (hold %1 s, an engineer does it in %2 s).", round (CQ_hackTime * CQ_hackSlowFactor), CQ_hackTime],
                   format ["Enemy radio tower: go to the field terminal at its foot and hold 'Hack radio tower' (%1 s).", CQ_hackTime]] select ((player getVariable ["CQ_class", ""]) == "Engineer"));
        };
    };
};

// nGD: engineers put a friendly relay on the tower site of a fallen enemy HQ (CQ_fnc_relayDeploy)
player addAction ["<t color='#918C3B'>Deploy relay (take over the node)</t>",
    { [player] remoteExec ["CQ_fnc_relayDeploy", 2] }, nil, 6, true, true, "",
    "vehicle _this == _this && { (_this getVariable ['CQ_class', '']) == 'Engineer' } && { ((missionNamespace getVariable ['CQ_relaySites', []]) findIf { _this distance2D (_x select 1) < CQ_relayRange }) > -1 }"];

// Hub menu (squads, class, stats, shop, debug): U key + one scroll menu entry (re-added on every respawn)
player addAction ["<t color='#918C3B'>Menu (U)</t>", { [] spawn CQ_fnc_menuUi }, nil, 0.6, false, true, "", "_this == _target"];
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

// Earplugs: one scroll menu entry + the End key, toggles the game sound down to CQ_earplugLevel
CQ_fnc_earplugs = {
    CQ_earplugs = !(missionNamespace getVariable ["CQ_earplugs", false]);
    1 fadeSound ([1, CQ_earplugLevel] select CQ_earplugs);
    hintSilent (["Earplugs out", "Earplugs in"] select CQ_earplugs);
};
player addAction ["<t color='#918C3B'>Earplugs (End)</t>", { call CQ_fnc_earplugs }, nil, 0.59, false, true, "", "_this == _target"];
if (isNil "CQ_earplugKeyBound") then {
    CQ_earplugKeyBound = true;
    [] spawn {
        waitUntil { sleep 0.5; !isNull (findDisplay 46) };
        (findDisplay 46) displayAddEventHandler ["KeyDown", {
            params ["", "_key", "_shift", "_ctrl", "_alt"];
            if (_key == 207 && { !_shift && !_ctrl && !_alt }) then { call CQ_fnc_earplugs; true } else { false };   // 207 = End
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
            if (_key == 61 && { isServer || { (call BIS_fnc_admin) == 2 } }) then { [] spawn CQ_fnc_debugUi; true } else { false };   // 61 = F3
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
        waitUntil { sleep 0.5; !isNil "CQ_arsenalBoxes" && { !isNil "CQ_vehBoxesDone" } };   // squad boxes + vehicle boxes
        {
            _x addAction [
                format ["<t color='#918C3B'>Arsenal (%1 equipment)</t>", _x getVariable ["CQ_squadBox", ""]],   // squad and vehicle boxes
                { [] spawn CQ_fnc_arsenalOpen },
                nil, 6, true, true, "", "true", 6
            ];
        } forEach CQ_arsenalBoxes;
        waitUntil { sleep 0.5; !isNil "CQ_shopTerminal" };
        CQ_shopTerminal addAction ["<t color='#918C3B'>Vehicle shop (squad points)</t>", { [] spawn CQ_fnc_shopUi }, nil, 6, true, true, "", "true", CQ_shopRange];
        waitUntil { sleep 0.5; !isNil "CQ_depots" };
        { (_x select 0) addAction ["<t color='#918C3B'>Vehicle depot (free stock)</t>", { [] spawn CQ_fnc_depotUi }, nil, 6, true, true, "", "true", CQ_depotRange] } forEach CQ_depots;
    };
};
