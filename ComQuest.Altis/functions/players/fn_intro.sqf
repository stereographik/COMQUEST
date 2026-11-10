/*
    CQ_fnc_intro  (client, spawned once at join from initPlayerLocal)
    Opens on black: time and place typed out in small letters (CQ_introPlace), then a fade.
    Contemplative cinematic, three long, slow shots joined by soft dips to black (CQ_introShots):
      1 SATELLITE  Altis from very high, almost still, a slow drift
      2 COCKPIT    pilot seat of a helicopter cruising slowly over the east coast, eyes on the
                   horizon (a local, unsimulated Ghost Hawk moved by script)
      3 CARRIER    far and low over the water, the carrier small on the horizon, the title
                   fading in late
    Then back to the player. Local only (nothing is created on the network). Skipped when
    CQ_introEnabled is false. Silent. Space skips it. Every player at join (late joiners too).
*/
if (!hasInterface || { !CQ_introEnabled }) exitWith {};
waitUntil { sleep 0.1; !isNull player && { !isNull (findDisplay 46) } };
private _t0 = time;
waitUntil { sleep 0.2; !isNil "CQ_carrierPos" || { time - _t0 > 8 } };
CQ_introShots params ["_t1", "_t2", "_t3"];
private _car = missionNamespace getVariable ["CQ_carrierPos", [worldSize * 0.85, worldSize * 0.5, 0]];

private _bl = "CQ_introBlack" call BIS_fnc_rscLayer;
_bl cutText ["", "BLACK FADED", 999];                       // black from the very first frame
showCinemaBorder true;
private _cam = "camera" camCreate (getPosATL player);
_cam cameraEffect ["internal", "back"];

// Space skips it: every pause below ends early, the remaining shots are skipped
CQ_introSkip = false;
private _skipEh = (findDisplay 46) displayAddEventHandler ["KeyDown", { params ["", "_k"]; if (_k == 57) then { CQ_introSkip = true; true } else { false } }];
private _nap = { params ["_t"]; private _e = time + _t; waitUntil { uiSleep 0.02; CQ_introSkip || { time >= _e } } };
call {
    // ---- 0 BLACK: time and place typed out, small and quiet, then a fade into the first shot
    private _tl = "CQ_introType" call BIS_fnc_rscLayer;
    _tl cutRsc ["RscTitleDisplayEmpty", "PLAIN", 0, false];
    private _td = uiNamespace getVariable ["RscTitleDisplayEmpty", displayNull];
    private _tc = _td ctrlCreate ["RscStructuredText", -1];
    _tc ctrlSetPosition [safeZoneX + safeZoneW * 0.08, safeZoneY + safeZoneH * 0.72, safeZoneW * 0.6, safeZoneH * 0.12];
    _tc ctrlCommit 0;
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
    for "_i" from 1 to 3 do { if (CQ_introSkip) exitWith {}; [_l1, _l2, false] call _show; [0.25] call _nap; [_l1, _l2, true] call _show; [0.25] call _nap };
    _tc ctrlSetFade 1;
    _tc ctrlCommit 0.5;
    [0.5] call _nap;
    _tl cutText ["", "PLAIN"];
    _bl cutText ["", "BLACK IN", 0.6];

    if (CQ_introSkip) exitWith {};
    // ---- 1 SATELLITE: high above the middle of the island, looking straight down
    private _mid = [worldSize * 0.5, worldSize * 0.5, 0];
    // contemplative: almost still, a slow drift and a barely noticeable push
    _cam camSetPos (_mid vectorAdd [-150, -120, 4600]);
    _cam camSetTarget _mid;
    _cam camSetFov 0.6;
    _cam camCommit 0;
    _cam camSetPos (_mid vectorAdd [150, -60, 4300]);
    _cam camSetFov 0.55;
    _cam camCommit (_t1 + 1.5);
    [_t1] call _nap;

    if (CQ_introSkip) exitWith {};
    // ---- 2 COCKPIT: pilot seat of a Ghost Hawk, low over the coast, heading for the carrier
    private _hdg = (CQ_basePos getDir _car);
    private _start = _car getPos [(_car distance2D CQ_basePos) * 0.55, _hdg + 180];
    private _h = createVehicleLocal ["B_Heli_Transport_01_F", [0, 0, 1000], [], 0, "CAN_COLLIDE"];
    _h enableSimulation false;
    _h allowDamage false;
    _h setDir _hdg;
    private _alt = 140;
    _h setPosASL [_start select 0, _start select 1, ((getTerrainHeightASL _start) max 0) + _alt];
    // pilot eye: a memory point named like the pilot view, else a measured fallback
    private _eye = [0.55, 3.55, -0.35];
    private _mp = (selectionNames [_h, "Memory"]) select { "pilot" in toLower _x && { "view" in toLower _x || { toLower _x == "pilot" } } };
    if (_mp isNotEqualTo []) then { private _p = _h selectionPosition [_mp select 0, "Memory"]; if (_p isNotEqualTo [0, 0, 0]) then { _eye = _p } };
    private _speed = 28;   // m/s: an unhurried flight
    private _tS = time + 0.5;
    private _end = _tS + _t2;
    private _dir = [sin _hdg, cos _hdg, 0];
    _bl cutText ["", "BLACK OUT", 0.5]; [0.5] call _nap;   // slow dip between shots
    private _first = true;
    while { time < _end && { !CQ_introSkip } } do {
        private _p = ([_start select 0, _start select 1, 0]) vectorAdd (_dir vectorMultiply (_speed * ((time - _tS) max 0)));
        _p set [2, ((getTerrainHeightASL _p) max 0) + _alt];
        _h setPosASL _p;
        _h setVectorDirAndUp [[sin _hdg, cos _hdg, -0.03], [0, 0, 1]];
        _cam camSetPos (_h modelToWorldVisual _eye);
        _cam camSetTarget (_h modelToWorldVisual (_eye vectorAdd [-8, 100, -3]));   // the horizon
        _cam camSetFov 0.75;
        _cam camCommit 0;
        if (_first) then { _first = false; _bl cutText ["", "BLACK IN", 0.6] };
        uiSleep 0.02;
    };
    deleteVehicle _h;

    if (CQ_introSkip) exitWith {};
    // ---- 3 CARRIER: slow dolly along the ship at sea level, title
    _bl cutText ["", "BLACK OUT", 0.5]; [0.5] call _nap;
    // far and low over the water, the ship small on the horizon, the camera barely moving
    private _from = _car vectorAdd [-1300, -500, 6];
    private _to = _car vectorAdd [-1250, -420, 7];
    _cam camSetPos _from;
    _cam camSetTarget (_car vectorAdd [0, 0, 20]);
    _cam camSetFov 0.32;
    _cam camCommit 0;
    _bl cutText ["", "BLACK IN", 0.8];
    _cam camSetPos _to;
    _cam camSetFov 0.28;
    _cam camCommit (_t3 + 2);
    [_t3 * 0.4] call _nap;
    titleText ["<t font='PuristaLight' size='1.6' color='#F2F1DF'>COMQUEST</t><br/><t font='PuristaLight' size='0.8' color='#A6A381'>CSAT CARRIER GROUP  ·  OFF ALTIS</t>", "PLAIN DOWN", 1.2, true, true];
    [_t3 * 0.6] call _nap;
};
// ---- back to the player
(findDisplay 46) displayRemoveEventHandler ["KeyDown", _skipEh];
_bl cutText ["", "BLACK OUT", 0.8];
uiSleep 0.8;
titleText ["", "PLAIN"];
("CQ_introType" call BIS_fnc_rscLayer) cutText ["", "PLAIN"];
if (!isNil "_h" && { !isNull _h }) then { deleteVehicle _h };
_cam cameraEffect ["terminate", "back"];
camDestroy _cam;
showCinemaBorder false;
_bl cutText ["", "BLACK IN", 0.6];
