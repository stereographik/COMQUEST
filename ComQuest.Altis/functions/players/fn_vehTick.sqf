/*
    CQ_fnc_vehTick  (server, director task)
    - Destroyed: respawn on its home spot CQ_vehRespawnDelay s after destruction.
    - Abandoned: empty, farther than CQ_vehAbandonDistance from base for CQ_vehAbandonDelay s,
      and no player within 200 m -> deleted and respawned at base.
    Polling (not a Killed event handler) on purpose: a vehicle driven by a player is local
    to that player, where a Killed handler added by the server would not fire.
*/
if (isNil "CQ_vehEntries") exitWith {};

{
    private _entry = _x;
    private _veh = _entry get "veh";

    if (isNull _veh || { !alive _veh }) then {
        if ((_entry get "deadSince") < 0) then {
            _entry set ["deadSince", serverTime];
            ["%1 destroyed, back in %2 s", [_entry get "class", CQ_vehRespawnDelay]] call CQ_fnc_log;
        };

        if (serverTime - (_entry get "deadSince") >= CQ_vehRespawnDelay) then {
            if (!isNull _veh) then { deleteVehicle _veh };
            [_entry] call CQ_fnc_vehSpawn;
        };
    } else {
        private _empty = ({ alive _x } count crew _veh) == 0;
        private _far = (_veh distance2D CQ_basePos) > CQ_vehAbandonDistance;

        if (_empty && _far) then {
            if ((_entry get "abandonedSince") < 0) then { _entry set ["abandonedSince", serverTime] };

            if (serverTime - (_entry get "abandonedSince") >= CQ_vehAbandonDelay) then {
                // Never make it vanish in front of a player
                if ((allPlayers findIf { alive _x && { _x distance _veh < 200 } }) == -1) then {
                    ["%1 abandoned at %2, returning to base", [_entry get "class", mapGridPosition _veh]] call CQ_fnc_log;
                    deleteVehicle _veh;
                    [_entry] call CQ_fnc_vehSpawn;
                };
            };
        } else {
            _entry set ["abandonedSince", -1];
        };
    };
} forEach CQ_vehEntries;
