/*
    CQ_fnc_magPhoto  (client, from CQ_fnc_magTick through remoteExec, on every machine)
    [_id, _vehicle, _drone] call CQ_fnc_magPhoto;
    The photo MAGPIE takes when a drone identifies a new enemy vehicle: a camera placed on the
    drone's line of sight to the vehicle (same angle as the UAV, seen from the drone's side),
    at a distance from the vehicle's bounding box so it fills the frame, renders into the
    128x128 texture "cq_ph_<slot>" (slot = _id mod CQ_magPhotoSlots). The next MAGPIE report
    shows it in a photo grid (CQ_fnc_storyUi).
    CQ_magPhotoFreeze: the camera is removed after CQ_magPhotoShot s (the texture keeps the last
    frame); false: the camera stays until CQ_magPhotoLife s (a live thumbnail, costs more).
    One camera at a time. Needs Picture-in-Picture on (video options), else the grid falls back
    to the vehicle's editor preview.
*/
params ["_id", "_o", ["_drone", objNull]];
if (!hasInterface || { isNull _o } || { !isPiPEnabled }) exitWith {};
if (isNil "CQ_magPhotoQ") then { CQ_magPhotoQ = [] };
CQ_magPhotoQ pushBack [_id, _o, _drone];
if (!isNil "CQ_magPhotoLoop") exitWith {};
CQ_magPhotoLoop = true;
[] spawn {
    while { CQ_magPhotoQ isNotEqualTo [] } do {
        (CQ_magPhotoQ deleteAt 0) params ["_id", "_o", "_drone"];
        if (isNull _o) then { continue };
        private _rtt = format ["cq_ph_%1", _id mod CQ_magPhotoSlots];
        // angle: from the drone (the UAV's own line of sight); no drone left -> from above, behind
        private _bb = boundingBoxReal _o;
        private _tgt = _o modelToWorldVisualWorld (((_bb select 0) vectorAdd (_bb select 1)) vectorMultiply 0.5);   // centre of the vehicle
        private _from = if (!isNull _drone) then { getPosASLVisual _drone } else { _tgt vectorAdd [-60 * sin (getDir _o), -60 * cos (getDir _o), 80] };
        private _u = vectorNormalized (_from vectorDiff _tgt);
        // distance: the bounding sphere fills CQ_magPhotoFill of the frame at CQ_magPhotoFov
        private _rad = (vectorMagnitude (((_bb select 1) vectorDiff (_bb select 0)) vectorMultiply 0.5)) max 1.5;
        private _dist = _rad / ((tan (deg (CQ_magPhotoFov / 2))) * CQ_magPhotoFill);
        private _pos = _tgt vectorAdd (_u vectorMultiply _dist);
        // never under the ground
        private _gnd = getTerrainHeightASL _pos;
        if ((_pos select 2) < _gnd + 2) then { _pos set [2, _gnd + 2] };
        private _cam = "camera" camCreate (ASLToAGL _pos);
        _cam setPosASL _pos;
        _cam cameraEffect ["Internal", "Back", _rtt];
        _cam camSetTarget (ASLToAGL _tgt);
        _cam camSetFov CQ_magPhotoFov;
        _cam camCommit 0;
        _rtt setPiPEffect [0];
        sleep CQ_magPhotoShot;          // a few frames: the scene streams in, the texture is drawn
        if (CQ_magPhotoFreeze) then {
            _cam cameraEffect ["Terminate", "Back", _rtt];
            camDestroy _cam;
        } else {
            [_cam, _rtt] spawn { params ["_c", "_r"]; sleep CQ_magPhotoLife; _c cameraEffect ["Terminate", "Back", _r]; camDestroy _c };
        };
    };
    CQ_magPhotoLoop = nil;
};
