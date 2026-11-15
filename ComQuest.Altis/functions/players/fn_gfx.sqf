/*
    CQ_fnc_gfx  (client)   graphics settings of this player, saved on this PC
    State CQ_gfx = [preset, view m, objects m, shadows m, terrain grid, animals, fps on screen]
      ["load"] call CQ_fnc_gfx;            saved values (profileNamespace "CQ_gfx_v1") or CQ_gfxDefault, applied
      ["preset", "High"] call CQ_fnc_gfx;  a preset from CQ_gfxPresets, applied
      ["set", [index, value]] call CQ_fnc_gfx;   one value (1 view, 2 objects, 3 shadows, 4 grid, 5 animals, 6 fps);
                                           the preset becomes "Custom" (except for the fps readout)
      ["apply"] / ["save"] call CQ_fnc_gfx;
    view: setViewDistance; objects + shadows: setObjectViewDistance (objects never past the view);
    grass: setTerrainGrid (50 = no grass); animals: enableEnvironment [animals, true] (ambient sounds kept)
*/
params ["_mode", ["_arg", []]];
if (!hasInterface) exitWith {};
private _fromPreset = {
    params ["_name"];
    private _p = CQ_gfxPresets select ((CQ_gfxPresets findIf { (_x select 0) == _name }) max 0);
    [_p select 0, _p select 1, _p select 2, _p select 3, _p select 4, _p select 5, missionNamespace getVariable ["CQ_gfxFps", false]]
};
switch (_mode) do {
    case "load": {
        private _s = profileNamespace getVariable ["CQ_gfx_v1", []];
        CQ_gfx = if (_s isEqualType [] && { count _s == 7 }) then { +_s } else { [CQ_gfxDefault] call _fromPreset };
        ["apply"] call CQ_fnc_gfx;
    };
    case "preset": {
        private _fps = (missionNamespace getVariable ["CQ_gfx", [0, 0, 0, 0, 0, 0, false]]) select 6;
        CQ_gfx = [_arg] call _fromPreset;
        CQ_gfx set [6, _fps];
        ["apply"] call CQ_fnc_gfx;
    };
    case "set": {
        _arg params ["_i", "_v"];
        CQ_gfx set [_i, _v];
        if (_i != 6) then { CQ_gfx set [0, "Custom"] };
        ["apply"] call CQ_fnc_gfx;
    };
    case "apply": {
        CQ_gfx params ["", "_vd", "_ovd", "_sh", "_grid", "_anim", "_fps"];
        setViewDistance _vd;
        setObjectViewDistance [_ovd min _vd, _sh];
        setTerrainGrid _grid;
        enableEnvironment [_anim, true];
        CQ_gfxFps = _fps;
        // FPS readout on the game screen (top centre)
        disableSerialization;
        private _c = uiNamespace getVariable ["CQ_fpsCtrl", controlNull];
        if (_fps && { isNull _c } && { !isNull findDisplay 46 }) then {
            _c = (findDisplay 46) ctrlCreate ["RscStructuredText", -1];
            _c ctrlSetPosition [safeZoneX + safeZoneW / 2 - 0.08, safeZoneY + 0.004, 0.16, 0.035];
            _c ctrlCommit 0;
            uiNamespace setVariable ["CQ_fpsCtrl", _c];
            [] spawn {
                disableSerialization;
                while { missionNamespace getVariable ["CQ_gfxFps", false] } do {
                    private _c = uiNamespace getVariable ["CQ_fpsCtrl", controlNull];
                    if (isNull _c) exitWith {};
                    private _f = round diag_fps;
                    private _ci = [0, [1, 2] select (_f >= 45)] select (_f >= 30);     // red < 30, amber < 45, green
                    _c ctrlSetStructuredText parseText format ["<t align='center' size='0.8' shadow='2' color='%1'>%2 FPS</t>", ["#F09595", "#FAC775", "#C0DD97"] select _ci, _f];
                    uiSleep 0.5;
                };
                ctrlDelete (uiNamespace getVariable ["CQ_fpsCtrl", controlNull]);
                uiNamespace setVariable ["CQ_fpsCtrl", controlNull];
            };
        };
    };
    case "save": {
        profileNamespace setVariable ["CQ_gfx_v1", +CQ_gfx];
        saveProfileNamespace;
    };
};
