/*
    CQ_fnc_hostageTick  (server, director task, every 2 s)
    The hostage event (see CQ_fnc_hostageStart):
      when      like the crash: the front has not moved for CQ_crashStagnant s, at most every
                CQ_crashCooldown s, never while a crash is running and CQ_hstGap s apart from it
      held      anyone reaching the hostage holds "Download firmware" on him (guards or not)
      extract   (CQ_fnc_hostageFirmware) players carry him to the helicopter (or any vehicle),
                guerillas chase him
      flight    aboard: the helicopter flies to the base; over the base perimeter = home
                (CQ_fnc_hostageEnd "home": Darter detection x CQ_hstBoost for CQ_hstBoostTime s)
      fail      the hostage dies, whoever killed him
*/
if (!CQ_hst) exitWith {};
if (time < (missionNamespace getVariable ["CQ_hstNext", 0])) exitWith {};
CQ_hstNext = time + 2;
if (isNil "CQ_hstLastT") then { CQ_hstLastT = -1e6 };

// ---- Darter boost over
private _bu = missionNamespace getVariable ["CQ_hstBoostUntil", -1];
if (_bu > 0 && { time >= _bu }) then {
    CQ_hstBoostUntil = -1; publicVariable "CQ_hstBoostUntil";
    ["Hostage event: Darter range boost over"] call CQ_fnc_log;
    ["hstBoostEnd", []] call CQ_fnc_say;
};

// ---- trigger
private _active = !isNil "CQ_hstState" && { (CQ_hstState get "phase") != "done" };
if (!_active) exitWith {
    if !(missionNamespace getVariable ["CQ_missionStarted", false]) exitWith {};
    if (time - CQ_hstLastT < CQ_crashCooldown) exitWith {};
    if (time - (missionNamespace getVariable ["CQ_crashLastT", -1e6]) < CQ_hstGap) exitWith {};
    if (!isNil "CQ_crashState" && { !(CQ_crashState get "secured") } && { time - (CQ_crashState get "t0") < CQ_crashCooldown }) exitWith {};
    if (time - (missionNamespace getVariable ["CQ_crashFrontT", 0]) < CQ_crashStagnant) exitWith {};
    ["Hostage event: triggered (front still for %1 min)", [round ((time - (missionNamespace getVariable ["CQ_crashFrontT", 0])) / 60)]] call CQ_fnc_log;
    if (call CQ_fnc_hostageStart) then { CQ_crashFrontT = time } else { CQ_hstLastT = time - CQ_crashCooldown + 120 };
};

private _s = CQ_hstState;
private _h = _s get "hostage";
if (!alive _h) exitWith { ["dead"] call CQ_fnc_hostageEnd };
private _ph = _s get "phase";
private _site = _s get "pos";

// home: over the base perimeter, by helicopter or any other way
if (_ph in ["extract", "flight"] && { _h distance2D CQ_basePos < CQ_baseRadius }) exitWith {
    private _v = _s get "heli";
    if (alive _v && { vehicle _h == _v }) then {
        private _lp = [CQ_basePos, 80, CQ_baseRadius, 16, 0, 0.25, 0, [], [CQ_basePos, CQ_basePos]] call BIS_fnc_findSafePos;
        private _pad = createVehicle ["Land_HelipadEmpty_F", [_lp select 0, _lp select 1, 0], [], 0, "CAN_COLLIDE"];
        _v doMove (getPosATL _pad);
        _v land "LAND";
        [_v, _h, _pad] spawn {
            params ["_v", "_h", "_pad"];
            waitUntil { sleep 2; !alive _v || { isTouchingGround _v && { speed _v < 3 } } };
            sleep 120;
            deleteVehicle _pad;
        };
    };
    ["home"] call CQ_fnc_hostageEnd;
};

switch (_ph) do {
    case "extract": {
        private _v = _s get "heli";
        if (!alive _v || { !canMove _v }) exitWith {
            ["Hostage event: extraction helicopter lost before he boarded, another one"] call CQ_fnc_log;
            ["hstHeliLost", []] call CQ_fnc_say;
            [_s] call CQ_fnc_hostageHeli;
            _s set ["stuckT", time]; _s set ["lastD", 1e6];
        };
        if (vehicle _h == _v) exitWith {
            _s set ["phase", "flight"];
            _v flyInHeight CQ_hstFlyHeight;
            _v doMove CQ_basePos;
            deleteMarker "cq_hst_lz";
            ["Hostage event: technician aboard, flying to the base (%1 m)", [round (_v distance2D CQ_basePos)]] call CQ_fnc_log;
            ["hstAboard", []] call CQ_fnc_say;
        };
        if (vehicle _h != _h) exitWith {};   // in one of our vehicles: on his way home another way
        private _d = _h distance2D _v;
        // the guerillas keep after him
        private _gg = _s get "guer";
        if (!isNull _gg && { time - (_s getOrDefault ["guerT", 0]) > 15 } && { ({ alive _x } count units _gg) > 0 }) then {
            _s set ["guerT", time];
            _gg reveal [_h, 4];
            _gg move (getPosATL _h);
        };
        if (time - (_s get "logT") > 30) then { _s set ["logT", time]; ["Hostage event: technician %1 m from the helicopter", [round _d]] call CQ_fnc_log };
    };
    case "flight": {
        private _v = _s get "heli";
        if (vehicle _h != _v) exitWith {
            // out of it (shot down and survived, bailed out): back to the extraction
            _s set ["phase", "extract"];
            ["Hostage event: the technician is out of the helicopter, new extraction"] call CQ_fnc_log;
            [_s] call CQ_fnc_hostageHeli;
            _s set ["stuckT", time]; _s set ["lastD", 1e6];
        };
        if (time - (_s get "logT") > 30) then {
            _s set ["logT", time];
            _v doMove CQ_basePos;
            ["Hostage event: extraction flight %1 m from the base", [round (_v distance2D CQ_basePos)]] call CQ_fnc_log;
        };
    };
};
