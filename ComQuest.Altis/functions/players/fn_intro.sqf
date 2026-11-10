/*
    CQ_fnc_intro  (client, spawned once at join from initPlayerLocal)
    Silent, contemplative intro, every player at join (late joiners too). Space skips to the
    ending. Nothing is created on the network: the helicopters are local and unsimulated
    (moved by script), deleted at the end; the player spawns at the usual muster area.
      0 BLACK      time and date, then the place (CQ_introPlace), typed small, then a fade
      1 SATELLITE  Altis from very high, almost still, a slow drift
      2 COAST      low and wide on a quiet east-coast village, calm sea, slow pan
      3 SQUAD      three guerilla fighters on a hilltop, sea behind, in a random scene: attack,
                   retreat, report, sneak or ambush (local soldiers, moves fitting the mood)
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
// black at once (no glimpse of the game), then wait until the loading screen is really gone:
// mission time running, the game display up, the client in game
("CQ_introBlack" call BIS_fnc_rscLayer) cutText ["", "BLACK FADED", 999];
waitUntil { sleep 0.1; !isNull player && { !isNull (findDisplay 46) } && { time > 0 } && { isServer || { getClientStateNumber >= 10 } } };
uiSleep CQ_introLoadPause;
private _t0 = time;
waitUntil { sleep 0.2; (!isNil "CQ_carrierPos" && { !isNil "CQ_musterPos" }) || { time - _t0 > 8 } };
CQ_introShots params ["_tSat", "_tCoast", "_tFlight", "_tLand"];   // _tFlight: the squad shot
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
    if (!isNil "CQ_introLandEh") then { removeMissionEventHandler ["EachFrame", CQ_introLandEh]; CQ_introLandEh = nil };
    { deleteVehicle _x } forEach (missionNamespace getVariable ["CQ_introLocals", []]);
    CQ_introLocals = [];
    CQ_introCam cameraEffect ["terminate", "back"]; camDestroy CQ_introCam; CQ_introCam = nil;
    if (!isNil "CQ_introView") then { setViewDistance (CQ_introView select 0); setObjectViewDistance (CQ_introView select 1) };
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

private _vdOld = viewDistance;
private _ovdOld = getObjectViewDistance;
CQ_introView = [_vdOld, _ovdOld];
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

// the landing Hummingbird is made now, hidden, engine running, parked high above a far corner
// of the map (out of earshot of every shot): by shot 4 its rotors are at full speed and its
// sound starts the moment it is brought to the pad. Local, no crew, nobody sees it but you.
private _lz = missionNamespace getVariable ["CQ_shopLZ", _muster getPos [35, CQ_baseDir + 90]];
private _lzDir = missionNamespace getVariable ["CQ_shopDir", CQ_baseDir];
private _gz = getTerrainHeightASL _lz;
private _hook = "Land_HelipadEmpty_F" createVehicleLocal [0, 0, 0];
_hook setPosASL [150, 150, 2500];          // far from every shot: its engine runs unheard until shot 4
_hook setDir _lzDir;
_locals pushBack _hook;
private _hb = createVehicleLocal ["B_Heli_Light_01_F", [0, 0, 1000], [], 0, "CAN_COLLIDE"];
_hb setVariable ["CQ_introVeh", true];
_hb allowDamage false;
_hb attachTo [_hook, [0, 0, 0]];
_hb hideObject true;
_hb engineOn true;
_locals pushBack _hb;

// ---- SPLASH (proof of concept), right after Arma's loading screen: black background, the
// mission visual centred (CQ_splashWidth of the screen width, whole picture, no crop), the
// text under it on its bottom-left corner. Holds CQ_splashTime s; Space ends it early.
if (CQ_splashEnabled) then {
    // black background (the black layer is already up), picture centred, text under it
    // aligned on the picture's bottom-left corner
    private _w = safeZoneW * CQ_splashWidth;
    private _h = (_w / pixelW) / 4 * pixelH;                    // 2048 x 512: 4:1 in screen pixels
    private _x0 = safeZoneX + (safeZoneW - _w) / 2;
    private _y0 = safeZoneY + (safeZoneH - _h) / 2 - safeZoneH * 0.05;
    private _sp = [];
    private _pic = _td ctrlCreate ["RscPicture", -1];
    _pic ctrlSetPosition [_x0, _y0, _w, _h];
    _pic ctrlSetText (getMissionPath "media\loading.jpg");
    _sp pushBack _pic;
    private _txt = _td ctrlCreate ["RscStructuredText", -1];
    _txt ctrlSetPosition [_x0, _y0 + _h + safeZoneH * 0.02, _w * 0.75, safeZoneH * 0.14];
    _txt ctrlSetStructuredText parseText format [
        "<t font='PuristaSemibold' size='1.3' color='#F2F1DF'>COMQUEST</t><t font='PuristaLight' size='0.75' color='#A6A381'>   v%1  ·  build %2</t><br/><t font='PuristaMedium' size='0.85' color='#F2F1DF'>ALTIS  ·  CUT THE NETWORK BEFORE THE CARRIER EMPTIES</t><br/><t font='PuristaLight' size='0.72' color='#A6A381'>Co-op, up to 26 players  ·  by Django aka stereographik</t>",
        CQ_version, CQ_build];
    _sp pushBack _txt;
    private _cont = _td ctrlCreate ["RscStructuredText", -1];
    _cont ctrlSetPosition [_x0 + _w * 0.75, _y0 + _h + safeZoneH * 0.02, _w * 0.25, safeZoneH * 0.04];
    _cont ctrlSetStructuredText parseText "<t align='right' font='PuristaLight' size='0.72' color='#918C3B'>SPACE  ·  continue</t>";
    _sp pushBack _cont;
    _hint ctrlShow false;
    { _x ctrlSetFade 1; _x ctrlCommit 0; _x ctrlSetFade 0; _x ctrlCommit 0.8 } forEach _sp;
    [CQ_splashTime] call _nap;
    { _x ctrlSetFade 1; _x ctrlCommit 0.8 } forEach _sp;
    uiSleep 0.8;
    { ctrlDelete _x } forEach _sp;
    _hint ctrlShow true;
    CQ_introSkip = false;                                       // Space here only ended the splash
};

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
    // under the cloud layer and with a long view distance for this shot only (restored after),
    // otherwise the ground fades out in the haze and nothing is visible from up there
    setViewDistance CQ_introViewDist;
    setObjectViewDistance [CQ_introViewDist * 0.5, 100];
    private _mid = [worldSize * 0.5, worldSize * 0.5, 0];
    _cam camSetPos (_mid vectorAdd [-120, -400, CQ_introSatAlt]);
    _cam camSetTarget (_mid vectorAdd [0, 200, 0]);
    _cam camSetFov 0.75;
    _cam camCommit 0;
    _bl cutText ["", "BLACK IN", CQ_introFade];
    _cam camSetPos (_mid vectorAdd [120, -340, CQ_introSatAlt - 80]);
    _cam camSetFov 0.7;
    _cam camCommit (_tSat + 1.5);
    [_tSat] call _nap;
    setViewDistance _vdOld;
    setObjectViewDistance _ovdOld;
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

    // ---- 3 SQUAD: three guerilla fighters on a hilltop, sea behind them, in one of 5 scenes
    // (attack, retreat, report, sneak, ambush), each man with moves that fit the mood.
    // Local, brainless soldiers driven by animations (only on your screen), deleted at the end.
    call _dip;
    if (CQ_introSkip) exitWith {};
    // highest ground within 2.5 km inland of the carrier's coast point, with the sea in view
    private _best = []; private _bh = -1e6;
    private _inland = _coast getDir CQ_basePos;
    for "_i" from 0 to 40 do {
        private _p = _coast getPos [600 + random 1900, _inland - 70 + random 140];
        if (surfaceIsWater _p) then { continue };
        private _h = getTerrainHeightASL _p;
        if (_h > _bh) then { _bh = _h; _best = _p };
    };
    if (_best isEqualTo []) then { _best = _coast getPos [800, _inland] };
    private _seaDir = _best getDir _car;                        // the sea is that way
    private _walkDir = _seaDir + 90;                            // they cross the frame
    // One of 5 scenes, picked at random (CQ_introScene in the settings forces one):
    //   0 ATTACK   1 RETREAT   2 REPORT (conversation)   3 SNEAK   4 AMBUSH
    // Each man has his own pool of moves for the mood of the scene: [move, gesture, min s, max s]
    // ("" = none; gesture "FIRE" = a short burst). He picks from it at random, never the same
    // entry twice in a row. Formation: [side offset, back offset, facing] (facing: "walk" along
    // the line, "back" toward where they came from, "lead" toward the leader, "sea").
    private _st  = "AmovPercMstpSrasWrflDnon";   private _low  = "AmovPercMstpSlowWrflDnon";
    private _wk  = "AmovPercMwlkSrasWrflDf";     private _wkL  = "AmovPercMwlkSlowWrflDf";
    private _run = "AmovPercMrunSrasWrflDf";     private _spr  = "AmovPercMevaSrasWrflDf";
    private _kn  = "AmovPknlMstpSrasWrflDnon";   private _knW  = "AmovPknlMwlkSrasWrflDf";
    private _knR = "AmovPknlMrunSrasWrflDf";     private _pr   = "AmovPpneMstpSrasWrflDnon";
    private _crl = "AmovPpneMrunSlowWrflDf";     private _wkB  = "AmovPercMwlkSrasWrflDb";
    private _knB = "AmovPknlMwlkSrasWrflDb";     private _runB = "AmovPercMrunSrasWrflDb";
    private _scenes = [
        ["ATTACK", _knR, [[0, 0, "walk"], [3, 5, "walk"], [-3, 8, "walk"]], [
            [[_knR, "", 1, 1.6], [_kn, "gestureAdvance", 1.2, 2], [_spr, "", 0.8, 1.2], [_kn, "gesturePoint", 1.2, 1.8], [_pr, "", 1.2, 2], [_kn, "FIRE", 1, 1.5]],
            [[_knR, "", 1, 1.6], [_spr, "", 0.8, 1.2], [_pr, "FIRE", 1.5, 2.2], [_kn, "FIRE", 1, 1.5], [_run, "", 0.8, 1.3]],
            [[_knR, "", 1, 1.6], [_spr, "", 0.8, 1.2], [_kn, "", 1, 1.6], [_pr, "", 1.5, 2.2], [_kn, "FIRE", 1, 1.5]]
        ]],
        ["RETREAT", _wkB, [[0, 0, "back"], [3, 4, "back"], [-3, 7, "back"]], [
            [[_wkB, "", 1.2, 2], [_knB, "", 1.2, 2], [_kn, "gestureFollow", 1.2, 1.8], [_kn, "gestureGo", 1.2, 1.8], [_runB, "", 0.8, 1.2], [_kn, "FIRE", 1, 1.4]],
            [[_wkB, "", 1.2, 2], [_knB, "", 1.2, 2], [_runB, "", 0.8, 1.2], [_kn, "FIRE", 1, 1.4], [_pr, "FIRE", 1.5, 2]],
            [[_knB, "", 1.2, 2], [_wkB, "", 1.2, 2], [_runB, "", 0.8, 1.2], [_kn, "", 1, 1.5]]
        ]],
        ["REPORT", _low, [[0, 0, "sea"], [2.2, 2.6, "lead"], [-2, 3, "lead"]], [
            [[_low, "gesturePoint", 1.6, 2.4], [_low, "gestureNod", 1.4, 2], [_low, "gestureNo", 1.4, 2], [_low, "gestureYes", 1.4, 2], [_low, "gestureCover", 1.6, 2.2], [_kn, "gesturePoint", 1.8, 2.6]],
            [[_low, "gestureNod", 1.5, 2.2], [_low, "gestureYes", 1.5, 2.2], [_low, "", 1.6, 2.4], [_kn, "", 2, 3], [_low, "gesturePoint", 1.6, 2.2]],
            [[_kn, "", 2, 3], [_low, "gestureNod", 1.5, 2.2], [_low, "gestureNo", 1.5, 2.2], [_st, "", 1.6, 2.4], [_kn, "gestureYes", 1.5, 2.2]]
        ]],
        ["SNEAK", _knW, [[0, 0, "walk"], [1.5, 4, "walk"], [-1.5, 8, "walk"]], [
            [[_knW, "", 1.6, 2.6], [_kn, "gestureFreeze", 1.6, 2.4], [_kn, "gestureFollow", 1.4, 2], [_kn, "gestureCover", 1.4, 2], [_pr, "", 1.6, 2.4], [_crl, "", 1.4, 2.2]],
            [[_knW, "", 1.6, 2.6], [_kn, "", 1.4, 2.2], [_pr, "", 1.6, 2.4], [_crl, "", 1.4, 2.2]],
            [[_knW, "", 1.6, 2.6], [_kn, "", 1.4, 2.2], [_crl, "", 1.4, 2.2], [_kn, "gestureNod", 1.2, 1.8]]
        ]],
        ["AMBUSH", _pr, [[0, 0, "sea"], [4, 2, "sea"], [-4, 2.5, "sea"]], [
            [[_pr, "", 1.8, 2.6], [_kn, "gestureFreeze", 1.6, 2.2], [_kn, "gestureCeaseFire", 1.6, 2.2], [_kn, "gesturePoint", 1.4, 2], [_pr, "", 1.8, 2.6]],
            [[_pr, "", 2, 3], [_crl, "", 1, 1.4], [_kn, "", 1.4, 2], [_pr, "", 2, 3]],
            [[_pr, "", 2, 3], [_kn, "", 1.4, 2], [_crl, "", 1, 1.4], [_pr, "gestureNod", 1.6, 2.2]]
        ]]
    ];
    private _si = missionNamespace getVariable ["CQ_introScene", -1];
    if (_si < 0 || { _si >= count _scenes }) then { _si = floor random count _scenes };
    (_scenes select _si) params ["_sName", "_sMove", "_sForm", "_sPools"];
    ["Intro squad scene: %1", [_sName]] call CQ_fnc_log;
    private _men = [];
    {
        (_sForm select _forEachIndex) params ["_side", "_back"];
        private _p = (_best getPos [_back, _walkDir + 180]) getPos [_side, _seaDir];
        private _u = (_x select 0) createVehicleLocal [0, 0, 0];
        _u setVariable ["CQ_introVeh", true];
        _u allowDamage false;
        _u setPosATL [_p select 0, _p select 1, 0];
        _u setDir _walkDir;
        _locals pushBack _u;
        _men pushBack _u;
    } forEach [["O_G_Soldier_SL_F"], ["O_G_Soldier_AR_F"], ["O_G_Soldier_LAT_F"]];
    {
        private _f = (_sForm select _forEachIndex) select 2;
        _x setDir (switch (_f) do {
            case "back": { _walkDir + 180 };
            case "sea":  { _seaDir };
            case "lead": { _x getDir (_men select 0) };
            default      { _walkDir };
        });
        _x switchMove _sMove;
        _x setVariable ["CQ_introNext", time + 0.3 + random 1.2];
        _x setVariable ["CQ_introLast", -1];
    } forEach _men;
    // REPORT: the leader faces his two men
    if (_sName == "REPORT") then { (_men select 0) setDir ((_men select 0) getDir (((getPosATL (_men select 1)) vectorAdd (getPosATL (_men select 2))) vectorMultiply 0.5)) };
    // camera inland of them, low, looking past the team to the sea
    private _cp = (_best getPos [26, _seaDir + 180]) getPos [6, _walkDir + 180];
    _cam camSetPos [_cp select 0, _cp select 1, 1.7];
    _cam camSetTarget ((_best getPos [120, _seaDir]) vectorAdd [0, 0, -10]);
    _cam camSetFov 0.6;
    _cam camCommit 0;
    _bl cutText ["", "BLACK IN", CQ_introFade];
    _cam camSetPos (([_cp select 0, _cp select 1, 0] getPos [6, _walkDir]) vectorAdd [0, 0, 1.8]);
    _cam camCommit _tFlight;                                    // slow drift with them
    private _tq = time;
    private _ambushed = false;
    while { time - _tq < _tFlight && { !CQ_introSkip } } do {
        // AMBUSH: at 70 % of the shot the leader springs it, everybody up on a knee and firing
        if (_sName == "AMBUSH" && { !_ambushed } && { time - _tq > _tFlight * 0.7 }) then {
            _ambushed = true;
            (_men select 0) playActionNow "gestureGo";
            { _x playMoveNow _kn; _x setVariable ["CQ_introNext", time + 0.4 + random 0.4]; _x setVariable ["CQ_introFireOnly", true] } forEach _men;
        };
        {
            private _u = _x;
            if (time < (_u getVariable "CQ_introNext")) then { continue };
            if (_u getVariable ["CQ_introFireOnly", false]) then {
                _u forceWeaponFire [primaryWeapon _u, currentWeaponMode _u];
                _u setVariable ["CQ_introNext", time + 0.15 + random 0.35];
                continue;
            };
            private _pool = _sPools select _forEachIndex;
            private _i = floor random count _pool;
            if (_i == (_u getVariable "CQ_introLast") && { count _pool > 1 }) then { _i = (_i + 1) mod count _pool };
            _u setVariable ["CQ_introLast", _i];
            (_pool select _i) params ["_mv", "_gs", "_t0", "_t1"];
            if (_mv != "") then { _u playMoveNow _mv };
            if (_gs == "FIRE") then {
                [_u] spawn { params ["_u"]; sleep 0.5; for "_k" from 1 to (2 + floor random 3) do { _u forceWeaponFire [primaryWeapon _u, currentWeaponMode _u]; sleep 0.18 } };
            } else { if (_gs != "") then { _u playActionNow _gs } };
            _u setVariable ["CQ_introNext", time + _t0 + random (_t1 - _t0)];
        } forEach _men;
        uiSleep 0.05;
    };
    if (CQ_introSkip) exitWith {};

    // ---- 4 LANDING: an empty Hummingbird settling at the muster area, seen from behind
    call _dip;
    if (CQ_introSkip) exitWith {};
    // a clear spot on/next to the pad (a vehicle may stand there), and no collision with what
    // stands around: the local helicopter must never touch, push or be pushed by a real vehicle
    private _fe = _lz findEmptyPosition [0, 30, "B_Heli_Light_01_F"];
    if (_fe isNotEqualTo []) then { _lz = [_fe select 0, _fe select 1, 0] };
    { _hb disableCollisionWith _x } forEach ((_lz nearObjects ["AllVehicles", 30]) + (nearestObjects [_lz, ["Static", "Thing"], 25]));
    private _behind = _lz getPos [24, _lzDir + 180];
    _cam camSetPos [_behind select 0, _behind select 1, 4];
    _cam camSetTarget [_lz select 0, _lz select 1, 1.5];
    _cam camSetFov 0.6;
    _cam camCommit 0;
    detach _hb;                                                 // engine already running: rotors at speed, sound at once
    _hb setPosASL ((AGLToASL [_lz select 0, _lz select 1, 0]) vectorAdd [0, 0, CQ_introHoverTop]);
    _hb setDir _lzDir;
    _hb hideObject false;
    // a slow vertical descent, from a few metres down to about 1 m above the pad, never touching.
    // Every frame the helicopter is given its next position through setVelocityTransformation:
    // the engine interpolates between frames, so the motion is perfectly smooth.
    // pre-warm: the descent and the engine sound start while the screen is still black, the
    // picture opens CQ_introPrewarm s later, the helicopter already moving and heard
    CQ_introLand = [_hb, _lz, _gz, _lzDir, time, _tLand + CQ_introPrewarm, time];
    CQ_introLandEh = addMissionEventHandler ["EachFrame", {
        CQ_introLand params ["_h", "_lz", "_gz", "_dir", "_t0", "_dur", "_tPrev"];
        private _f = {
            params ["_t"];
            private _k = ((_t - _t0) / _dur) max 0 min 1;
            private _s = _k * _k * (3 - 2 * _k);                // smoothstep: soft start, soft stop
            AGLToASL [_lz select 0, _lz select 1, 0] vectorAdd [0, 0, CQ_introHoverTop - (CQ_introHoverTop - CQ_introHoverLow) * _s]
        };
        private _p0 = [_tPrev] call _f;
        private _p1 = [time] call _f;
        private _v = if (time > _tPrev) then { (_p1 vectorDiff _p0) vectorMultiply (1 / (time - _tPrev)) } else { [0, 0, 0] };
        private _vd = [sin _dir, cos _dir, 0];
        _h setVelocityTransformation [_p0, _p1, _v, _v, _vd, _vd, [0, 0, 1], [0, 0, 1], 1];
        CQ_introLand set [6, time];
    }];
    [CQ_introPrewarm] call _nap;
    _bl cutText ["", "BLACK IN", CQ_introFade];
    [_tLand] call _nap;
    // the handler keeps it hovering at its last height until the screen is black (removed below)
};

// ---- 5 BLACK, then 6 EYES: the player's own view opens in two blinks, a blur clearing
_bl cutText ["", "BLACK OUT", CQ_introFade];
uiSleep CQ_introFade;
if (!isNil "CQ_introLandEh") then { removeMissionEventHandler ["EachFrame", CQ_introLandEh]; CQ_introLandEh = nil; CQ_introLand = nil };
(findDisplay 46) displayRemoveEventHandler ["KeyDown", _skipEh];
_tl cutText ["", "PLAIN"];
{ deleteVehicle _x } forEach _locals;
CQ_introLocals = [];
_cam cameraEffect ["terminate", "back"];
camDestroy _cam;
CQ_introCam = nil;
setViewDistance _vdOld;
setObjectViewDistance _ovdOld;
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
{ deleteVehicle _x } forEach ((allMissionObjects "All") select { local _x && { _x getVariable ["CQ_introVeh", false] } });
