/*
    CQ_fnc_empClient  (client)
    ["init"] call CQ_fnc_empClient;      once (initPlayerLocal): no UAV terminal ever connects to a
                                         drone (MAGPIE's or the EMP Stomper): the captured EMP's
                                         terminal is only a targeting token
    ["setup"] call CQ_fnc_empClient;     every spawn (CQ_fnc_playerSetup): hit -> a running EMP
                                         defuse hold restarts (CQ_empHitT); "Program EMP target"
                                         while carrying the terminal of a defused EMP
    ["program"] spawn CQ_fnc_empClient;  pin the target on the map, then confirm (once, final)
    ["fx", [_pos, _r, _time, _hits]] call CQ_fnc_empClient;   the shockwave (see "fx")
*/
params ["_mode", ["_args", []]];
if (!hasInterface) exitWith {};
switch (_mode) do {
    case "init": {
        [] spawn {
            private _done = [];
            while { true } do {
                {
                    if !(_x in _done) then { player disableUAVConnectability [_x, true]; _done pushBack _x };
                } forEach allUnitsUAV;
                _done = _done select { !isNull _x };
                sleep 5;
            };
        };
    };
    case "setup": {
        player addEventHandler ["Hit", { (_this select 0) setVariable ["CQ_empHitT", time] }];
        player addAction ["<t color='#E8A33D'>Program EMP target</t>", { ["program"] spawn CQ_fnc_empClient }, nil, 1.1, false, true, "",
            "alive _this && { (missionNamespace getVariable ['CQ_empPhase', '']) == 'defused' } && { !(missionNamespace getVariable ['CQ_empProgrammed', false]) } && { 'B_UavTerminal' in ((assignedItems _this) + (items _this)) }"];
    };
    case "program": {
        if (missionNamespace getVariable ["CQ_empProgrammed", false]) exitWith {};
        CQ_empPick = [];
        openMap true;
        hint parseText "<t color='#E8A33D' size='1.1'>EMP TARGET</t><br/>Click the map where the EMP must go off.<br/>Close the map to cancel.";
        private _eh = addMissionEventHandler ["MapSingleClick", {
            params ["", "_pos"];
            CQ_empPick = _pos;
        }];
        waitUntil { sleep 0.1; CQ_empPick isNotEqualTo [] || { !visibleMap } };
        removeMissionEventHandler ["MapSingleClick", _eh];
        hintSilent "";
        if (CQ_empPick isEqualTo []) exitWith {};
        private _pos = +CQ_empPick;
        private _mk = createMarkerLocal ["cq_emp_pick", _pos];
        _mk setMarkerTypeLocal "mil_destroy";
        _mk setMarkerColorLocal "ColorOrange";
        _mk setMarkerTextLocal " EMP target?";
        private _ok = [parseText format ["Program the EMP to go off at grid %1?<br/><br/>This choice is final: the terminal is used up, and the Stomper drives there on its own once the device is loaded.", mapGridPosition _pos], "EMP TARGET", "PROGRAM", "CANCEL"] call BIS_fnc_guiMessage;
        deleteMarkerLocal _mk;
        if (_ok && { !(missionNamespace getVariable ["CQ_empProgrammed", false]) }) then { [player, _pos] remoteExec ["CQ_fnc_empProgram", 2] };
    };
    case "fx": {
        // the shockwave (cinematic): core flash; a ring of dust and shimmering air sweeping the
        // ground near this player; a short sharp shake and a rumble as it passes the player; as it
        // reaches each hit object, a jagged blue-white lightning bolt from the EMP to it (3 flickers),
        // with a flash, sparks and a crackle there. Only what is near this player is drawn.
        _args params ["_pos", "_r", ["_time", 5], ["_hits", []]];
        [_pos, _r, _time, _hits] spawn {
            params ["_pos", "_r", "_time", "_hits"];
            private _spd = _r / (_time max 0.5);
            private _t0 = time;
            private _pd = player distance2D _pos;
            private _view = 1500;                               // m around the player where particles are drawn
            private _base = ATLToASL [_pos select 0, _pos select 1, 0];
            // core flash
            if (_pd < _r + _view) then {
                private _l = "#lightpoint" createVehicleLocal (_pos vectorAdd [0, 0, 25]);
                _l setLightColor [0.55, 0.75, 1];
                _l setLightAmbient [0.45, 0.65, 1];
                _l setLightBrightness 60;
                _l setLightAttenuation [10, 0, 0, 0.00005];
                [_l] spawn { params ["_l"]; for "_i" from 1 to 12 do { _l setLightBrightness (60 * (1 - _i / 12)); sleep 0.08 }; deleteVehicle _l };
                playSound3D ["a3\sounds_f\ambient\thunder\thunder_01.wss", objNull, false, _base, 5, 0.7, 6000];
            };
            // one lightning bolt: jagged path EMP -> object, 3 flickers of glowing dots
            private _bolt = {
                params ["_from", "_o"];
                if (isNull _o) exitWith {};
                private _to = (getPosASL _o) vectorAdd [0, 0, 1.2];
                if ((player distance2D _o) > _view && { (player distance2D _from) > _view }) exitWith {};
                private _len = _from vectorDistance _to;
                private _n = (round (_len / 25)) max 4 min 60;
                for "_f" from 1 to 3 do {
                    private _pts = [_from];
                    for "_i" from 1 to (_n - 1) do {
                        private _k = _i / _n;
                        private _q = (_from vectorMultiply (1 - _k)) vectorAdd (_to vectorMultiply _k);
                        private _j = (_len * 0.025) * sin (180 * _k);       // jagged, widest mid-way
                        _pts pushBack (_q vectorAdd [(random 2 - 1) * _j, (random 2 - 1) * _j, (random 2 - 1) * _j * 0.6 + _j * 0.4]);
                    };
                    _pts pushBack _to;
                    for "_i" from 1 to (count _pts - 1) do {
                        private _a = _pts select (_i - 1);
                        private _b = _pts select _i;
                        private _sl = _a vectorDistance _b;
                        private _m = (ceil (_sl / 3)) max 1;
                        for "_d" from 0 to _m do {
                            private _c = (_a vectorMultiply (1 - _d / _m)) vectorAdd (_b vectorMultiply (_d / _m));
                            if (player distance2D _c < _view) then {
                                drop [["\A3\data_f\ParticleEffects\Universal\Universal", 16, 13, 1, 0], "", "Billboard", 1, 0.12,
                                    ASLToAGL _c, [0, 0, 0], 0, 1.275, 1, 0, [1.2, 0.8], [[0.75, 0.88, 1, 1], [0.6, 0.8, 1, 0.6]], [1], 0, 0, "", "", ""];
                            };
                        };
                    };
                    sleep 0.09;
                };
                // at the object: flash, sparks, crackle
                if (player distance2D _o < _view) then {
                    private _l = "#lightpoint" createVehicleLocal (ASLToAGL _to);
                    _l setLightColor [0.55, 0.75, 1];
                    _l setLightAmbient [0.4, 0.6, 1];
                    _l setLightBrightness 6;
                    _l setLightAttenuation [2, 0, 0, 0.05];
                    for "_i" from 1 to 25 do {
                        drop [["\A3\data_f\ParticleEffects\Universal\Universal", 16, 13, 1, 0], "", "Billboard", 1, 0.5 + random 0.4,
                            ASLToAGL _to, [(random 8) - 4, (random 8) - 4, 2 + random 5], 0, 2, 1, 0.1, [0.25, 0.08], [[1, 0.95, 0.7, 1], [0.6, 0.8, 1, 0]], [1], 0, 0, "", "", ""];
                    };
                    playSound3D ["a3\sounds_f\sfx\special_sfx\sparkles_wreck_1.wss", objNull, false, _to, 3, 1, 400];
                    [_l] spawn { params ["_l"]; sleep 0.6; deleteVehicle _l };
                };
            };
            private _queue = _hits apply { [_x, _x distance2D _pos] };
            private _shaken = false;
            private _from = _base vectorAdd [0, 0, 3];
            while { time - _t0 <= _time + 0.3 } do {
                private _rad = (time - _t0) * _spd;
                // the ring near the player: dust and shimmering air on the arc within ~800 m of him
                if (_rad > 5 && { _rad <= _r } && { abs (_rad - _pd) < 800 }) then {
                    private _a0 = _pos getDir player;
                    private _span = ((800 / _rad) * 57.3) min 180;
                    private _steps = ((round (2 * _span * _rad / 57.3 / 45)) max 4) min 40;
                    for "_i" from 0 to _steps do {
                        private _a = _a0 - _span + _i * (2 * _span / _steps);
                        private _q = _pos getPos [_rad, _a];
                        private _out = [sin _a, cos _a, 0] vectorMultiply 25;
                        drop [["\A3\data_f\ParticleEffects\Universal\Universal", 16, 12, 13, 0], "", "Billboard", 1, 1.6,
                            [_q select 0, _q select 1, 1.5], _out vectorAdd [0, 0, 3], 0, 1.275, 1, 0.4, [5, 14], [[0.78, 0.8, 0.82, 0.45], [0.75, 0.78, 0.8, 0]], [0.5], 0, 0, "", "", ""];
                        drop [["\A3\data_f\ParticleEffects\Universal\Refract", 1, 0, 1], "", "Billboard", 1, 0.8,
                            [_q select 0, _q select 1, 2.5], _out, 0, 1.275, 1, 0, [8, 18], [[1, 1, 1, 0.4], [1, 1, 1, 0]], [1], 0, 0, "", "", ""];
                    };
                };
                // it passes the player: short sharp shake and a rumble
                if (!_shaken && { _rad >= _pd } && { _pd <= _r }) then {
                    _shaken = true;
                    addCamShake [7, 0.6, 28];
                    playSound3D ["a3\sounds_f\ambient\thunder\thunder_02.wss", objNull, false, getPosASL player, 3, 1.4, 100];
                };
                // bolts as the wave reaches each hit object
                {
                    if ((_x select 1) <= _rad) then { [_from, _x select 0] spawn _bolt; _x set [1, 1e9] };
                } forEach _queue;
                sleep 0.05;
            };
        };
    };
};
