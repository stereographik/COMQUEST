/*
    CQ_fnc_hqTick  (server, director task, every CQ_tickSeconds)
    Drives every HQ through its lifecycle:
      Securing      squads post out to the 1 km perimeter          -> all posted (or timeout)
      Installing    4 build stages (CQ_fnc_hqBuild, spawned)       -> buildDone
      Hold          holds CQ_holdTime                              -> requests a wave
      WaitingReinf  convoy on its way (CQ_fnc_waveSend)            -> arrived: CQ_fnc_hqSplit
      Holding       defends until the next wave (CQ_waveInterval)  -> requests a wave
    In every state: contact -> CQ_fnc_callReinf (heli + QRF), QRF groups return after
    CQ_qrfTime. Helicopters: CQ_fnc_airTick. Ammo: CQ_fnc_logiTick.
    Destroyed: commander dead or captured AND every installation destroyed (depot, radio
    tower, fuel tanker, AA guns, HMG tower). Failed: wiped out before being built.
*/
private _now = time;

{
    private _hq = _y;
    private _state = _hq get "state";
    if !(_state in CQ_activeStates) then { continue };
    if (_state == "Inbound") then { continue };   // insertion / colonist scripts own it
    private _id = _hq get "id";

    // ---- losses
    if !(_hq get "buildDone") then {
        if ((([_hq get "infantry"] call CQ_fnc_aliveCount) + ([[_hq get "cmdGroup"]] call CQ_fnc_aliveCount)) == 0) then {
            _hq set ["state", "Failed"];
            { deleteMarker _x } forEach (_hq get "markers");
            ["Enemy HQ wiped out", format ["HQ #%1 was destroyed before it could be built", _id]] call CQ_fnc_announce;
            if (_hq get "secureStarted") then { ["fallenEarly", [[_id] call CQ_fnc_objName]] call CQ_fnc_say };
        };
    } else {
        // nGD: an HQ falls when its radio tower is down and its commander is killed or captured;
        // the other objectives (AA, HMG, depot, tanker) are optional tactical targets
        private _cmdGone = !alive (_hq get "commander") || { _hq get "cmdCaptured" };
        if (_cmdGone && { !alive (_hq get "radio") }) then {
            _hq set ["state", "Destroyed"];
            { deleteMarker _x } forEach (_hq get "markers");
            if (_hq get "buildDone") then { [_hq] call CQ_fnc_hqNerves };
    [_hq] call CQ_fnc_hqStatusMarker;
            ["Enemy HQ destroyed", format ["HQ #%1 has fallen. Enemy AI left on the map: %2", _id, call CQ_fnc_enemyCount]] call CQ_fnc_announce;
            ["fallen", [[_id] call CQ_fnc_objName, { (_x get "state") in CQ_activeStates } count (values CQ_hqs)]] call CQ_fnc_say;
            if (isNil "CQ_relays") then { CQ_relays = [] };
            call CQ_fnc_relaySites;          // an engineer can now put a relay on its tower site
            [_hq] spawn CQ_fnc_hqFallen;     // its depot, tanker, aircraft and troops stop serving it
        };
    };
    _state = _hq get "state";
    if !(_state in CQ_activeStates) then { continue };
    [_hq] call CQ_fnc_hqStatusMarker;

    // ---- contact -> call for reinforcements
    if (_now - (_hq get "lastContactT") > CQ_contactCooldown) then {
        private _ct = [_hq] call CQ_fnc_hqContact;
        if (_ct isNotEqualTo []) then { [_hq, _ct select 0, _ct param [2, grpNull]] call CQ_fnc_callReinf };
    };

    // ---- QRF groups come home
    private _c = _hq get "pos";
    {
        if ((_x getVariable ["CQ_role", ""]) == "qrf" && { _now > (_x getVariable ["CQ_qrfUntil", 0]) }) then {
            [_x] call CQ_fnc_clearWaypoints;
            _x setVariable ["CQ_role", "patrol"];
            _x setSpeedMode "NORMAL";
            [_x, _c, CQ_patrolRadius select 0] call CQ_fnc_infPatrol;
            ["HQ #%1: a QRF squad returns to patrol", [_id]] call CQ_fnc_log;
        };
    } forEach ((_hq get "infantry") select { !isNull _x });

    // ---- lifecycle
    switch (_state) do {
        case "Securing": {
            if !(_hq get "secureStarted") then {
                [_hq] call CQ_fnc_hqSecure;
            } else {
                // Secured once every squad is CQ_secureShare of the way out (they keep walking to their posts)
                private _pending = (_hq get "infantry") select {
                    alive leader _x
                    && { (_x getVariable ["CQ_role", ""]) == "secure" }
                    && { (leader _x) distance2D _c < CQ_secureRadius * CQ_secureShare }
                    && { (leader _x) distance2D (_x getVariable ["CQ_securePos", getPosATL leader _x]) > 80 }
                };
                private _timeout = _now - (_hq get "stateT") > CQ_secureTimeout;
                if (_pending isEqualTo [] || _timeout) then {
                    _hq set ["state", "Installing"];
                    _hq set ["stateT", _now];
                    _hq set ["buildStarted", true];
                    ["Enemy perimeter secured", format ["HQ #%1: perimeter %2, installing the HQ at grid %3",
                        _id, ["secured", "partly secured (timeout)"] select _timeout, mapGridPosition _c]] call CQ_fnc_announce;
                    [_hq] spawn CQ_fnc_hqBuild;
                };
            };
        };
        case "Installing": {
            if (_hq get "buildDone") then {
                _hq set ["state", "Hold"];
                _hq set ["stateT", _now];
                ["Enemy HQ installed", format ["HQ #%1 is operational, holding position for %2 s", _id, CQ_holdTime]] call CQ_fnc_announce;
            };
        };
        case "Hold": {
            if (_now - (_hq get "stateT") >= CQ_holdTime) then { [_hq] call CQ_fnc_hqRequestWave };
        };
        case "Holding": {
            if (_now >= (_hq get "nextWaveT")) then { [_hq] call CQ_fnc_hqRequestWave };
        };
        case "WaitingReinf": {
            private _res = _hq get "waveResult";
            if (_res isNotEqualTo []) then {
                _hq set ["waveResult", []];
                ([_hq] + _res) call CQ_fnc_hqSplit;
            };
        };
    };
} forEach CQ_hqs;

// ---- victory: no HQ left, and the carrier cannot send more (all roots landed or no supplies)
if (isNil "CQ_victory" && { CQ_rootsLaunched >= CQ_maxRoots || { (missionNamespace getVariable ["CQ_carrierLeft", 1]) <= 0 } }) then {
    if (((values CQ_hqs) findIf { (_x get "state") in CQ_activeStates }) == -1) then {
        CQ_victory = true;
        ["VICTORY", "The carrier has nothing left to send and every enemy HQ is destroyed"] call CQ_fnc_announce;
        ["victory", []] call CQ_fnc_say;
        [] spawn { sleep 15; "EveryoneWon" call BIS_fnc_endMissionServer };
    };
};
