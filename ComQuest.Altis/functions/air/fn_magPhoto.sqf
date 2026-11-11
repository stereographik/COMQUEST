/*
    CQ_fnc_magPhoto  (client)
    MAGPIE's photos of the vehicles her drones identify, shown as a grid under her report
    (CQ_fnc_storyUi). A render-to-texture surface does not keep its picture once its camera is
    gone (the photo turns black), so a photo is a LIVE thumbnail: its camera exists only while
    the report card is on screen.
      ["shot", [_id, _vehicle, _drone]]   from CQ_fnc_magTick through remoteExec, every machine:
          remembers the vehicle and the drone's line of sight to it when it was identified
          (CQ_magPhotoInfo: id -> [vehicle, unit vector vehicle -> drone])
      ["start", [_id]] -> camera or objNull   CQ_fnc_storyUi, when the card appears:
          camera on that line of sight, at a distance from the vehicle's bounding box so it
          fills the frame (CQ_magPhotoFov, CQ_magPhotoFill), rendering into "cq_ph_<slot>";
          it follows the vehicle every frame (moving vehicles stay in the picture)
      ["stop", [_cam]]   CQ_fnc_storyUi, when the card goes
    Without Picture-in-Picture (video options), or once the vehicle is gone, nothing is rendered:
    the card shows the vehicle's editor preview instead.
*/
params ["_mode", ["_args", []]];
if (!hasInterface) exitWith { objNull };
if (isNil "CQ_magPhotoInfo") then { CQ_magPhotoInfo = createHashMap };
if (isNil "CQ_magPhotoCams") then { CQ_magPhotoCams = [] };

switch (_mode) do {
    case "shot": {
        _args params ["_id", "_o", ["_drone", objNull]];
        if (isNull _o) exitWith { objNull };
        private _bb = boundingBoxReal _o;
        private _tgt = _o modelToWorldVisualWorld (((_bb select 0) vectorAdd (_bb select 1)) vectorMultiply 0.5);
        private _from = if (!isNull _drone) then { getPosASLVisual _drone } else { _tgt vectorAdd [0, -60, 80] };
        CQ_magPhotoInfo set [_id, [_o, vectorNormalized (_from vectorDiff _tgt)]];
        objNull
    };
    case "start": {
        _args params ["_id"];
        (CQ_magPhotoInfo getOrDefault [_id, []]) params [["_o", objNull], ["_u", [0, -0.6, 0.8]]];
        if (!isPiPEnabled || { isNull _o } || { !alive _o }) exitWith { objNull };
        private _rtt = format ["cq_ph_%1", _id mod CQ_magPhotoSlots];
        private _bb = boundingBoxReal _o;
        private _ctr = ((_bb select 0) vectorAdd (_bb select 1)) vectorMultiply 0.5;
        private _rad = (vectorMagnitude (((_bb select 1) vectorDiff (_bb select 0)) vectorMultiply 0.5)) max 1.5;
        private _dist = _rad / ((tan (deg (CQ_magPhotoFov / 2))) * CQ_magPhotoFill);
        private _tgt = _o modelToWorldVisualWorld _ctr;
        private _p0 = _tgt vectorAdd (_u vectorMultiply _dist);
        private _cam = "camera" camCreate (ASLToAGL _p0);
        _cam setVariable ["CQ_ph", [_o, _u vectorMultiply _dist, _ctr, _rtt]];
        _cam cameraEffect ["Internal", "Back", _rtt];
        // camera commands only (camSetPos / camSetTarget + camCommit): setPos* on a camera is
        // overridden by its committed state and it ends up staring at the sky
        _cam camSetPos (ASLToAGL _p0);
        _cam camSetTarget _o;              // locked on the vehicle: follows it by itself
        _cam camSetFov CQ_magPhotoFov;
        _cam camCommit 0;
        _rtt setPiPEffect [0];
        CQ_magPhotoCams pushBack _cam;
        // one frame handler moves every live photo camera with its vehicle
        if (isNil "CQ_magPhotoEh") then {
            CQ_magPhotoEh = addMissionEventHandler ["EachFrame", {
                CQ_magPhotoCams = CQ_magPhotoCams select { !isNull _x };
                {
                    (_x getVariable ["CQ_ph", []]) params ["_o", "_off", "_ctr"];
                    if (isNull _o) then { continue };
                    private _t = _o modelToWorldVisualWorld _ctr;
                    private _p = _t vectorAdd _off;
                    private _g = getTerrainHeightASL _p;
                    if ((_p select 2) < _g + 2) then { _p set [2, _g + 2] };
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
        private _rtt = (_cam getVariable ["CQ_ph", [objNull, [], [], ""]]) select 3;
        _cam cameraEffect ["Terminate", "Back", _rtt];
        camDestroy _cam;
        objNull
    };
    default { objNull };
};
