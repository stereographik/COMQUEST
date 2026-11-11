/*
    CQ_fnc_magPhoto  (client, from CQ_fnc_magTick through remoteExec, every machine)
    ["shot", [_id, _target, _drone]] call CQ_fnc_magPhoto;
    The still photo MAGPIE takes the moment a drone identifies a new enemy (vehicle or soldier),
    shown in a grid under her next report (CQ_fnc_storyUi):
      - angle: the drone's own line of sight to the target
      - distance: CQ_magPhotoDist (12 m) from a vehicle, CQ_magPhotoDistInf (3 m) from a soldier
      - the camera renders into "cq_ph_<slot>" for CQ_magPhotoShot s, then is removed: the
        texture keeps that frame (a still, not a live view)
    No picture is possible while the full-screen map is open (no 3D rendering there): the shot
    waits in the queue and is taken as soon as the map is closed, from the same drone angle,
    if the target is still alive and the shot is not older than CQ_magPhotoMaxDelay s. Without
    Picture-in-Picture, or too late, the card shows the editor preview of the class instead
    (CQ_magPhotoOk: id -> true once the shot was taken; an open card swaps to the photo then).
    One camera at a time (queue).
*/
params ["_mode", ["_args", []]];
if (!hasInterface) exitWith {};
if (isNil "CQ_magPhotoOk") then { CQ_magPhotoOk = createHashMap };
if (isNil "CQ_magPhotoQ") then { CQ_magPhotoQ = [] };
if (_mode != "shot") exitWith {};
_args params ["_id", "_o", ["_drone", objNull]];
if (isNull _o) exitWith {};
private _from = if (!isNull _drone) then { getPosASLVisual _drone } else { (getPosASLVisual _o) vectorAdd [0, -60, 80] };
CQ_magPhotoQ pushBack [_id, _o, _from, time];
if (!isNil "CQ_magPhotoLoop") exitWith {};
CQ_magPhotoLoop = true;
[] spawn {
    while { CQ_magPhotoQ isNotEqualTo [] } do {
        // map open: no 3D rendering, the shots wait until it is closed
        if (visibleMap) then { sleep 0.5; continue };
        (CQ_magPhotoQ deleteAt 0) params ["_id", "_o", "_from", "_t0"];
        if (isNull _o || { !alive _o } || { !isPiPEnabled } || { time - _t0 > CQ_magPhotoMaxDelay }) then { continue };
        private _rtt = format ["cq_ph_%1", _id mod CQ_magPhotoSlots];
        private _bb = boundingBoxReal _o;
        private _tgt = _o modelToWorldVisualWorld (((_bb select 0) vectorAdd (_bb select 1)) vectorMultiply 0.5);
        private _dist = [CQ_magPhotoDist, CQ_magPhotoDistInf] select (_o isKindOf "CAManBase");
        private _pos = _tgt vectorAdd ((vectorNormalized (_from vectorDiff _tgt)) vectorMultiply _dist);
        private _g = getTerrainHeightASL _pos;
        if ((_pos select 2) < _g + 1.5) then { _pos set [2, _g + 1.5] };
        private _cam = "camera" camCreate (ASLToAGL _pos);
        _cam cameraEffect ["Internal", "Back", _rtt];
        _cam camSetPos (ASLToAGL _pos);
        _cam camSetTarget (ASLToAGL _tgt);
        _cam camSetFov CQ_magPhotoFov;
        _cam camCommit 0;
        _rtt setPiPEffect [0];
        sleep CQ_magPhotoShot;            // a few frames: the scene streams in, the texture is drawn
        private _ok = !visibleMap;
        _cam cameraEffect ["Terminate", "Back", _rtt];
        camDestroy _cam;
        if (_ok) then { CQ_magPhotoOk set [_id, true] } else { CQ_magPhotoQ pushBack [_id, _o, _from, _t0] };   // map opened mid-shot: again later
    };
    CQ_magPhotoLoop = nil;
};
