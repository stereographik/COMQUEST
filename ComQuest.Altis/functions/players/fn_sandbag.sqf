/*
    CQ_fnc_sandbag
    Engineers build short sandbag walls in the field.
      client  ["place"] spawn CQ_fnc_sandbag      ghost in front of the engineer: Q / E turn it,
                                                  the scroll menu confirms or cancels; then a
                                                  CQ_sbBuildTime s build (stay still, on foot)
      server  ["build",  [_unit, _pos, _dir]]     checks the cap and creates the wall
      server  ["recall", [_unit]]                 removes every wall this player left (in base only)
    Walls are indestructible and belong to the player's UID (CQ_sbWalls), not to his body: the
    cap (CQ_sbMax) holds through death, respawn and reconnects. Count published as CQ_sb_<uid>.
*/
params ["_mode", ["_args", []]];

switch (_mode) do {

    case "place": {
        if (!hasInterface) exitWith {};
        if (!isNil "CQ_sbGhost") exitWith {};
        private _uid = getPlayerUID player;
        if ((missionNamespace getVariable ["CQ_sb_" + _uid, 0]) >= CQ_sbMax) exitWith {
            hint format ["You already have %1 sandbag walls out there. Recall them from the base.", CQ_sbMax];
        };
        CQ_sbGhost = CQ_sbClass createVehicleLocal [0, 0, 0];
        CQ_sbGhost enableSimulation false;
        CQ_sbGhost allowDamage false;
        CQ_sbRot = 0;
        CQ_sbState = 0;            // 0 placing, 1 confirmed, -1 cancelled
        private _kh = (findDisplay 46) displayAddEventHandler ["KeyDown", {
            params ["", "_k"];
            if (_k == 16) exitWith { CQ_sbRot = CQ_sbRot - 15; true };   // Q
            if (_k == 18) exitWith { CQ_sbRot = CQ_sbRot + 15; true };   // E
            false
        }];
        private _a1 = player addAction ["<t color='#918C3B'>Build the sandbag wall here</t>", { CQ_sbState = 1 }, nil, 10, true, true, "", "true"];
        private _a2 = player addAction ["<t color='#BA392C'>Cancel the sandbag wall</t>", { CQ_sbState = -1 }, nil, 9.9, false, true, "", "true"];
        private _ok = false;
        private _pos = [0, 0, 0];
        while { CQ_sbState == 0 && { alive player } && { vehicle player == player } } do {
            _pos = player getPos [2.6, getDir player];
            CQ_sbGhost setDir (getDir player + 90 + CQ_sbRot);
            CQ_sbGhost setPosATL [_pos select 0, _pos select 1, 0];
            CQ_sbGhost setVectorUp surfaceNormal _pos;
            _ok = ["valid", [_pos]] call CQ_fnc_sandbag;
            hintSilent parseText format ["<t size='1.1'>Sandbag wall</t><br/>Q / E to turn<br/><t color='%1'>%2</t>",
                ["#BA392C", "#918C3B"] select (_ok isEqualTo ""), [_ok, "Good spot"] select (_ok isEqualTo "")];
            sleep 0.02;
        };
        private _dir = getDir CQ_sbGhost;
        _pos = getPosATL CQ_sbGhost;
        deleteVehicle CQ_sbGhost;
        CQ_sbGhost = nil;
        (findDisplay 46) displayRemoveEventHandler ["KeyDown", _kh];
        player removeAction _a1; player removeAction _a2;
        hintSilent "";
        if (CQ_sbState != 1) exitWith {};
        private _why = ["valid", [_pos]] call CQ_fnc_sandbag;
        if (_why isNotEqualTo "") exitWith { hint _why };
        // the build: stay put CQ_sbBuildTime s
        private _here = getPosATL player;
        player playAction "Medic";
        private _t = time;
        private _done = false;
        waitUntil {
            sleep 0.2;
            hintSilent format ["Building the sandbag wall... %1 s", ceil (CQ_sbBuildTime - (time - _t))];
            if (!alive player || { vehicle player != player } || { player distance _here > 1.5 }) exitWith { true };
            if (round (time - _t) mod 3 == 0) then { player playAction "Medic" };
            if (time - _t >= CQ_sbBuildTime) exitWith { _done = true; true };
            false
        };
        hintSilent "";
        if (!_done) exitWith { hint "Sandbag wall cancelled." };
        ["build", [player, _pos, _dir]] remoteExec ["CQ_fnc_sandbag", 2];
    };

    // "" when a wall can stand here, else the reason
    case "valid": {
        _args params ["_p"];
        if (_p distance2D CQ_basePos < CQ_baseRadius) exitWith { "Not inside the base." };
        if (surfaceIsWater _p) exitWith { "Not in the water." };
        if (((surfaceNormal _p) select 2) < CQ_sbMaxSlope) exitWith { "Too steep here." };
        if ((nearestTerrainObjects [_p, ["BUILDING", "HOUSE", "WALL", "FENCE", "ROCK", "ROCKS", "TREE"], 1.8, false]) isNotEqualTo []) exitWith { "Something is in the way." };
        if (((_p nearObjects ["Building", 2.5]) + (_p nearEntities [["LandVehicle", "Air", "StaticWeapon"], 4])) findIf { _x != (missionNamespace getVariable ["CQ_sbGhost", objNull]) && { typeOf _x != CQ_sbClass } } > -1) exitWith { "Something is in the way." };
        ""
    };

    case "build": {
        if (!isServer) exitWith {};
        _args params ["_unit", "_pos", "_dir"];
        private _uid = getPlayerUID _unit;
        if (isNil "CQ_sbWalls") then { CQ_sbWalls = createHashMap };
        private _mine = (CQ_sbWalls getOrDefault [_uid, []]) select { !isNull _x };
        if (count _mine >= CQ_sbMax || { !(_unit getUnitTrait "engineer") } || { (["valid", [_pos]] call CQ_fnc_sandbag) isNotEqualTo "" }) exitWith {
            ["Sandbag wall refused."] remoteExec ["hint", _unit];
        };
        private _w = createVehicle [CQ_sbClass, [0, 0, 0], [], 0, "CAN_COLLIDE"];
        _w setDir _dir;
        _w setPosATL [_pos select 0, _pos select 1, 0];
        _w setVectorUp surfaceNormal _pos;
        _w allowDamage false;
        _w setVariable ["CQ_sbOwner", _uid, true];
        _mine pushBack _w;
        CQ_sbWalls set [_uid, _mine];
        missionNamespace setVariable ["CQ_sb_" + _uid, count _mine, true];
        [format ["Sandbag wall built (%1/%2). Recall your walls from the base.", count _mine, CQ_sbMax]] remoteExec ["hint", _unit];
        ["%1 built a sandbag wall at grid %2 (%3/%4)", [name _unit, mapGridPosition _w, count _mine, CQ_sbMax]] call CQ_fnc_log;
    };

    case "recall": {
        if (!isServer) exitWith {};
        _args params ["_unit"];
        if (_unit distance2D CQ_basePos > CQ_baseRadius) exitWith {};
        private _uid = getPlayerUID _unit;
        if (isNil "CQ_sbWalls") then { CQ_sbWalls = createHashMap };
        private _mine = (CQ_sbWalls getOrDefault [_uid, []]) select { !isNull _x };
        { deleteVehicle _x } forEach _mine;
        CQ_sbWalls set [_uid, []];
        missionNamespace setVariable ["CQ_sb_" + _uid, 0, true];
        [format ["%1 sandbag wall%2 recalled.", count _mine, ["s", ""] select (count _mine == 1)]] remoteExec ["hint", _unit];
        ["%1 recalled %2 sandbag walls", [name _unit, count _mine]] call CQ_fnc_log;
    };
};
