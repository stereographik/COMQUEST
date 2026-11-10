/*
    CQ_fnc_intro  (client, spawned once at join from initPlayerLocal)
    Silent, contemplative intro, every player at join (late joiners too). Space skips to the
    ending. Nothing is created on the network: the helicopters are local and unsimulated
    (moved by script), deleted at the end; the player spawns at the usual muster area.
      0 BLACK      time and date, then the place (CQ_introPlace), typed small, then a fade
      1 SATELLITE  Altis from very high, almost still, a slow drift
      2 COAST      low and wide on a quiet east-coast village, calm sea, slow pan
      3 FLIGHT     CSAT Orcas low over the water, heading for the island
      4 LANDING    an MH-9 Hummingbird settling at the muster area, seen from behind
      5 BLACK      fade out
      6 EYES       the player's own view opens in two blinks, a blur clearing: control
    Shot lengths: CQ_introShots [satellite, coast, flight, landing]. When it ends (or is
    skipped, or CQ_introEnabled is false) the server is told: the mission starts
    CQ_startAfterIntro s after the FIRST player's intro (CQ_fnc_introDone).
*/
if (!hasInterface) exitWith {};
private _done = { [] remoteExec ["CQ_fnc_introDone", 2] };
if (!CQ_introEnabled) exitWith { call _done };
waitUntil { sleep 0.1; !isNull player && { !isNull (findDisplay 46) } };
private _t0 = time;
waitUntil { sleep 0.2; (!isNil "CQ_carrierPos" && { !isNil "CQ_musterPos" }) || { time - _t0 > 8 } };
CQ_introShots params ["_tSat", "_tCoast", "_tFlight", "_tLand"];
private _car = missionNamespace getVariable ["CQ_carrierPos", [worldSize * 0.85, worldSize * 0.5, 0]];
private _coast = missionNamespace getVariable ["CQ_coastPoint", _car getPos [3000, 270]];
private _muster = missionNamespace getVariable ["CQ_musterPos", getPosATL player];
CQ_introLocals = [];            // everything the intro creates, deleted at its end
private _locals = CQ_introLocals;

private _bl = "CQ_introBlack" call BIS_fnc_rscLayer;
_bl cutText ["", "BLACK FADED", 999];
showCinemaBorder true;
private _cam = "camera" camCreate (getPosATL player);
_cam cameraEffect ["internal", "back"];
CQ_introCam = _cam;
// watchdog: whatever happens to the intro (script error, freeze), after CQ_introMaxTime s every
// trace is removed and the player gets his view back
[] spawn {
    uiSleep CQ_introMaxTime;
    if (isNil "CQ_introCam") exitWith {};
    { deleteVehicle _x } forEach (missionNamespace getVariable ["CQ_introLocals", []]);
    CQ_introLocals = [];
    CQ_introCam cameraEffect ["terminate", "back"]; camDestroy CQ_introCam; CQ_introCam = nil;
    showCinemaBorder false;
    ("CQ_introType" call BIS_fnc_rscLayer) cutText ["", "PLAIN"];
    ("CQ_introBlack" call BIS_fnc_rscLayer) cutText ["", "BLACK IN", 0.5];
    [] remoteExec ["CQ_fnc_introDone", 2];
    diag_log text "[CQ] intro watchdog: cleaned up";
};

// text layer: the typed lines + the skip hint
private _tl = "CQ_introType" call BIS_fnc_rscLayer;
_tl cutRsc ["RscTitleDisplayEmpty", "PLAIN", 0, false];
private _td = uiNamespace getVariable ["RscTitleDisplayEmpty", displayNull];
private _tc = _td ctrlCreate ["RscStructuredText", -1];
_tc ctrlSetPosition [safeZoneX + safeZoneW * 0.08, safeZoneY + safeZoneH * 0.72, safeZoneW * 0.6, safeZoneH * 0.12];
_tc ctrlCommit 0;
private _hint = _td ctrlCreate ["RscStructuredText", -1];
_hint ctrlSetPosition [safeZoneX + safeZoneW * 0.8, safeZoneY + safeZoneH * 0.93, safeZoneW * 0.17, safeZoneH * 0.04];
_hint ctrlCommit 0;
_hint ctrlSetStructuredText parseText "<t align='right' font='PuristaLight' size='0.7' color='#A6A381'>SPACE  ·  skip</t>";

CQ_introSkip = false;
private _skipEh = (findDisplay 46) displayAddEventHandler ["KeyDown", { params ["", "_k"]; if (_k == 57) then { CQ_introSkip = true; true } else { false } }];
private _nap = { params ["_t"]; private _e = time + _t; waitUntil { uiSleep 0.02; CQ_introSkip || { time >= _e } } };
private _dip = {     // dip to black between two shots: CQ_introFade out, CQ_introFade in
    _bl cutText ["", "BLACK OUT", CQ_introFade];
    [CQ_introFade] call _nap;
};
private _local = {   // a local, unsimulated vehicle
    params ["_cls", "_pos", "_dir"];
    private _v = createVehicleLocal [_cls, [0, 0, 1000], [], 0, "CAN_COLLIDE"];
    _v enableSimulation false;
    _v allowDamage false;
    _v setVariable ["CQ_introVeh", true];
    _v setDir _dir;
    _v setPosASL _pos;
    _locals pushBack _v;
    _v
};

// the landing Hummingbird is made now, hidden, engine running: its rotors are at full speed by
// shot 4. It hangs on a local helper moved by script (no crew, nobody can see it but you).
private _lz = missionNamespace getVariable ["CQ_shopLZ", _muster getPos [35, CQ_baseDir + 90]];
private _lzDir = missionNamespace getVariable ["CQ_shopDir", CQ_baseDir];
private _gz = getTerrainHeightASL _lz;
private _hook = "Land_HelipadEmpty_F" createVehicleLocal [0, 0, 0];
_hook setPosASL [_lz select 0, _lz select 1, _gz + 23];
_hook setDir _lzDir;
_locals pushBack _hook;
private _hb = createVehicleLocal ["B_Heli_Light_01_F", [0, 0, 1000], [], 0, "CAN_COLLIDE"];
_hb setVariable ["CQ_introVeh", true];
_hb allowDamage false;
_hb attachTo [_hook, [0, 0, 0]];
_hb hideObject true;
_hb engineOn true;
_locals pushBack _hb;

call {
    // ---- 0 BLACK: time and place typed out
    date params ["_y", "_mo", "_d", "_hh", "_mm"];
    private _months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
    private _l1 = format ["%1%2:%3%4  ·  %5 %6 %7", ["", "0"] select (_hh < 10), _hh, ["", "0"] select (_mm < 10), _mm, _d, _months select (_mo - 1), _y];
    private _l2 = CQ_introPlace;
    private _show = {
        params ["_a", "_b", ["_cursor", true]];
        _tc ctrlSetStructuredText parseText format [
            "<t font='PuristaLight' size='0.78' color='#F2F1DF'>%1</t><br/><t font='PuristaLight' size='0.78' color='#A6A381'>%2%3</t>",
            _a, _b, ["", "_"] select _cursor];
    };
    [0.4] call _nap;
    for "_i" from 1 to count _l1 do { if (CQ_introSkip) exitWith {}; [_l1 select [0, _i], ""] call _show; [CQ_introTypeDelay] call _nap };
    for "_i" from 1 to count _l2 do { if (CQ_introSkip) exitWith {}; [_l1, _l2 select [0, _i]] call _show; [CQ_introTypeDelay] call _nap };
    for "_i" from 1 to 2 do { if (CQ_introSkip) exitWith {}; [_l1, _l2, false] call _show; [0.25] call _nap; [_l1, _l2, true] call _show; [0.25] call _nap };
    _tc ctrlSetFade 1;
    _tc ctrlCommit 0.5;
    [0.5] call _nap;
    if (CQ_introSkip) exitWith {};

    // ---- 1 SATELLITE
    private _mid = [worldSize * 0.5, worldSize * 0.5, 0];
    _cam camSetPos (_mid vectorAdd [-150, -120, 4600]);
    _cam camSetTarget _mid;
    _cam camSetFov 0.6;
    _cam camCommit 0;
    _bl cutText ["", "BLACK IN", CQ_introFade];
    _cam camSetPos (_mid vectorAdd [150, -60, 4300]);
    _cam camSetFov 0.55;
    _cam camCommit (_tSat + 1.5);
    [_tSat] call _nap;
    if (CQ_introSkip) exitWith {};

    // ---- 2 COAST: the village nearest to the carrier's coast point, seen from the sea
    call _dip;
    if (CQ_introSkip) exitWith {};
    private _vil = nearestLocations [_coast, ["NameVillage", "NameCity", "NameLocal"], 5000];
    private _vp = if (_vil isNotEqualTo []) then { locationPosition (_vil select 0) } else { _coast };
    _vp = [_vp select 0, _vp select 1, 0];
    private _seaDir = _vp getDir _car;                         // from the village toward the sea
    private _cp = _vp getPos [700, _seaDir];
    _cam camSetPos [_cp select 0, _cp select 1, 18];
    _cam camSetTarget (_vp getPos [80, _seaDir + 25]);
    _cam camSetFov 0.42;
    _cam camCommit 0;
    _bl cutText ["", "BLACK IN", CQ_introFade];
    _cam camSetTarget (_vp getPos [80, _seaDir - 25]);          // slow pan along the shore
    _cam camCommit (_tCoast + 0.8);
    [_tCoast] call _nap;
    if (CQ_introSkip) exitWith {};

    // ---- 3 FLIGHT: three Orcas low over the water toward the island, camera just above the waves
    call _dip;
    if (CQ_introSkip) exitWith {};
    private _hdg = _car getDir _coast;
    private _mid3 = _car getPos [(_car distance2D _coast) * 0.5, _hdg];
    private _from = _mid3 getPos [180, _hdg + 180];
    private _helis = [[0, 0], [-35, -30], [35, -45]] apply {
        _x params ["_dx", "_dy"];
        private _p = _from getPos [sqrt (_dx * _dx + _dy * _dy), _hdg + (_dx atan2 _dy)];
        [["O_Heli_Light_02_unarmed_F", [_p select 0, _p select 1, 35 + random 6], _hdg] call _local, [_p select 0, _p select 1]]
    };
    private _cp3 = _mid3 getPos [90, _hdg + 90];
    _cam camSetPos [_cp3 select 0, _cp3 select 1, 3];
    _cam camSetTarget [_from select 0, _from select 1, 30];
    _cam camSetFov 0.55;
    _cam camCommit 0;
    _bl cutText ["", "BLACK IN", CQ_introFade];
    private _tS = time;
    private _dir = [sin _hdg, cos _hdg, 0];
    while { time - _tS < _tFlight && { !CQ_introSkip } } do {
        private _k = 45 * (time - _tS);                          // 45 m/s
        {
            _x params ["_v", "_p0"];
            private _p = ([_p0 select 0, _p0 select 1, 0]) vectorAdd (_dir vectorMultiply _k);
            _v setPosASL [_p select 0, _p select 1, (getPosASL _v) select 2];
            _v setVectorDirAndUp [[sin _hdg, cos _hdg, -0.12], [0, 0, 1]];
        } forEach _helis;
        _cam camSetTarget (getPosASL ((_helis select 0) select 0));
        _cam camCommit 0;
        uiSleep 0.02;
    };
    if (CQ_introSkip) exitWith {};

    // ---- 4 LANDING: an empty Hummingbird settling at the muster area, seen from behind
    call _dip;
    if (CQ_introSkip) exitWith {};
    private _behind = _lz getPos [20, _lzDir + 180];
    _cam camSetPos [_behind select 0, _behind select 1, 7];
    _cam camSetTarget [_lz select 0, _lz select 1, 1.5];
    _cam camSetFov 0.6;
    _cam camCommit 0;
    _hb hideObject false;
    _bl cutText ["", "BLACK IN", CQ_introFade];
    private _tL = time;
    while { time - _tL < _tLand && { !CQ_introSkip } } do {
        private _k = ((time - _tL) / (_tLand * 0.85)) min 1;
        private _ease = 1 - (1 - _k) ^ 2;                        // slows down as it settles
        _hook setPosASL [_lz select 0, _lz select 1, _gz + 22 * (1 - _ease) + 1.1];
        _hook setVectorDirAndUp [[sin _lzDir, cos _lzDir, 0.04 * (1 - _ease)], [0, 0, 1]];
        uiSleep 0.02;
    };
};

// ---- 5 BLACK, then 6 EYES: the player's own view opens in two blinks, a blur clearing
_bl cutText ["", "BLACK OUT", CQ_introFade];
uiSleep CQ_introFade;
(findDisplay 46) displayRemoveEventHandler ["KeyDown", _skipEh];
_tl cutText ["", "PLAIN"];
{ deleteVehicle _x } forEach _locals;
CQ_introLocals = [];
_cam cameraEffect ["terminate", "back"];
camDestroy _cam;
CQ_introCam = nil;
showCinemaBorder false;
call _done;
private _blur = ppEffectCreate ["DynamicBlur", 450];
_blur ppEffectEnable true;
_blur ppEffectAdjust [6];
_blur ppEffectCommit 0;
uiSleep 0.3;
_bl cutText ["", "BLACK IN", 0.35];       // half open...
_blur ppEffectAdjust [3];
_blur ppEffectCommit 0.4;
uiSleep 0.4;
_bl cutText ["", "BLACK OUT", 0.15];      // ...a blink...
uiSleep 0.2;
_bl cutText ["", "BLACK IN", 0.7];        // ...open
_blur ppEffectAdjust [0];
_blur ppEffectCommit 1.2;
uiSleep 1.3;
_blur ppEffectEnable false;
ppEffectDestroy _blur;
CQ_introSkip = nil;
// last check: no intro vehicle may survive (local, but never left in the world)
{ deleteVehicle _x } forEach ((allMissionObjects "Helicopter") select { local _x && { !simulationEnabled _x } && { _x getVariable ["CQ_introVeh", false] } });
