/*
    CQ_fnc_empClient  (client)
    ["init"] call CQ_fnc_empClient;      once (initPlayerLocal): no UAV terminal ever connects to a
                                         drone (MAGPIE's or the EMP Stomper): the captured EMP's
                                         terminal is only a targeting token
    ["setup"] call CQ_fnc_empClient;     every spawn (CQ_fnc_playerSetup): hit -> a running EMP
                                         defuse hold restarts (CQ_empHitT); "Program EMP target"
                                         while carrying the terminal of a defused EMP
    ["program"] spawn CQ_fnc_empClient;  pin the target on the map, then confirm (once, final)
    ["fx", [_pos, _r]] call CQ_fnc_empClient;   flash and shake where an EMP went off
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
        _args params ["_pos", "_r"];
        private _d = player distance2D _pos;
        if (_d > _r * 1.5) exitWith {};
        private _l = "#lightpoint" createVehicleLocal (_pos vectorAdd [0, 0, 30]);
        _l setLightColor [0.6, 0.8, 1];
        _l setLightAmbient [0.5, 0.7, 1];
        _l setLightBrightness 40;
        _l setLightAttenuation [10, 0, 0, 0.0001];
        addCamShake [4 * (1 - (_d / (_r * 1.5)) max 0.2), 2, 15];
        [_l] spawn { params ["_l"]; sleep 1.5; deleteVehicle _l };
    };
};
