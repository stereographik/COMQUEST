/*
    CQ_fnc_magPhoto  (client)
    MAGPIE's photos of the enemies her drones identify, shown in a grid under her next report
    (CQ_fnc_storyUi). Arma clears a render-to-texture surface as soon as its camera is removed
    (a frozen still turns black), so each thumbnail is a camera that exists only while its
    report card is on screen:
      ["shot", [_id, _target, _drone]]   from CQ_fnc_magTick (remoteExec, every machine), the
          moment the drone identifies the target: remembers the target, the drone's line of
          sight to it (unit vector) and where it stood (CQ_magPhotoInfo: id -> [obj, dir, pos])
      ["start", [_id]] -> camera or objNull   CQ_fnc_storyUi, card on screen and map closed:
          camera on that line of sight, CQ_magPhotoDist (12 m) from a vehicle,
          CQ_magPhotoDistInf (3 m) from a soldier, rendering into "cq_ph_<slot>"; it follows the
          target (camSetPos every frame, aim locked on it); target dead or gone: it stays on
          the spot where the target was seen
      ["stop", [_cam]]   CQ_fnc_storyUi, card gone
    Without Picture-in-Picture: objNull (the card shows the editor preview).
*/
params ["_mode", ["_args", []]];
if (!hasInterface) exitWith { objNull };
if (isNil "CQ_magPhotoInfo") then { CQ_magPhotoInfo = createHashMap };
if (isNil "CQ_magPhotoCams") then { CQ_magPhotoCams = [] };

// where the camera stands for a target: centre of the target + dir x distance, above the ground
private _camPos = {
    params ["_o", "_dir", "_spot"];
    private _tgt = if (alive _o) then {
        private _bb = boundingBoxReal _o;
        _o modelToWorldVisualWorld (((_bb select 0) vectorAdd (_bb select 1)) vectorMultiply 0.5)
    } else { _spot };
    private _d = [CQ_magPhotoDist, CQ_magPhotoDistInf] select (!isNull _o && { _o isKindOf "CAManBase" });
    private _p = _tgt vectorAdd (_dir vectorMultiply _d);
    private _g = getTerrainHeightASL _p;
    if ((_p select 2) < _g + 1.5) then { _p set [2, _g + 1.5] };
    [_p, _tgt]
};

if (isNil "CQ_magPhotoCamPos") then { CQ_magPhotoCamPos = _camPos };   // for the frame handler

switch (_mode) do {
    case "shot": {
        _args params ["_id", "_o", ["_drone", objNull]];
        if (isNull _o) exitWith { objNull };
        private _bb = boundingBoxReal _o;
        private _tgt = _o modelToWorldVisualWorld (((_bb select 0) vectorAdd (_bb select 1)) vectorMultiply 0.5);
        private _from = if (!isNull _drone) then { getPosASLVisual _drone } else { _tgt vectorAdd [0, -60, 80] };
        CQ_magPhotoInfo set [_id, [_o, vectorNormalized (_from vectorDiff _tgt), _tgt]];
        objNull
    };
    case "start": {
        _args params ["_id"];
        private _info = CQ_magPhotoInfo getOrDefault [_id, []];
        if (_info isEqualTo [] || { !isPiPEnabled }) exitWith { objNull };
        private _rtt = format ["cq_ph_%1", _id mod CQ_magPhotoSlots];
        (_info call _camPos) params ["_p", "_t"];
        private _cam = "camera" camCreate (ASLToAGL _p);
        _cam setVariable ["CQ_ph", _info + [_rtt]];
        _cam cameraEffect ["Internal", "Back", _rtt];
        _cam camSetPos (ASLToAGL _p);
        if (alive (_info select 0)) then { _cam camSetTarget (_info select 0) } else { _cam camSetTarget (ASLToAGL _t) };
        _cam camSetFov CQ_magPhotoFov;
        _cam camCommit 0;
        _rtt setPiPEffect [0];
        CQ_magPhotoCams pushBack _cam;
        // one frame handler keeps every photo camera on its target
        if (isNil "CQ_magPhotoEh") then {
            CQ_magPhotoEh = addMissionEventHandler ["EachFrame", {
                CQ_magPhotoCams = CQ_magPhotoCams select { !isNull _x };
                {
                    private _i = _x getVariable ["CQ_ph", []];
                    if (_i isEqualTo [] || { !alive (_i select 0) }) then { continue };   // dead: stays where it was seen
                    ((_i select [0, 3]) call (missionNamespace getVariable "CQ_magPhotoCamPos")) params ["_p"];
                    _x camSetPos (ASLToAGL _p);
                    _x camCommit 0;
                } forEach CQ_magPhotoCams;
                if (CQ_magPhotoCams isEqualTo []) then {
                    removeMissionEventHandler ["EachFrame", CQ_magPhotoEh];
                    CQ_magPhotoEh = nil;
                };
            }];
        };
        _cam
    };
    case "stop": {
        _args params ["_cam"];
        if (isNull _cam) exitWith { objNull };
        _cam cameraEffect ["Terminate", "Back", (_cam getVariable ["CQ_ph", [0, 0, 0, ""]]) select 3];
        camDestroy _cam;
        objNull
    };
    default { objNull };
};
