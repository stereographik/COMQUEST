/*
    CQ_fnc_tabletBg  (client)
    [_d, [_picX, _picY, _pw, _ph], [[[x, y, w, h], colour], ...]] call CQ_fnc_tabletBg;
    The field tablet's background (picture media\comtablet_ca.paa + the given panels, screen
    positions) inside one full-screen controls group, created first on the window. Plain controls
    created first were not drawn over the open map (the later ones were); a controls group keeps
    them at the back and drawn (BI forums, "CtrlCreate draw order"). Returns the group.
*/
params ["_d", "_pic", ["_panels", []]];
disableSerialization;
private _g = _d ctrlCreate ["RscControlsGroupNoScrollbars", -1];
_g ctrlSetPosition [safeZoneX, safeZoneY, safeZoneW, safeZoneH];
_g ctrlCommit 0;
_pic params ["_px", "_py", "_pw", "_ph"];
private _p = _d ctrlCreate ["RscPicture", -1, _g];
_p ctrlSetPosition [_px - safeZoneX, _py - safeZoneY, _pw, _ph];
_p ctrlSetText (getMissionPath "media\comtablet_ca.paa");
_p ctrlCommit 0;
{
    _x params ["_r", "_col"];
    private _t = _d ctrlCreate ["RscText", -1, _g];
    _t ctrlSetPosition [(_r select 0) - safeZoneX, (_r select 1) - safeZoneY, _r select 2, _r select 3];
    _t ctrlSetBackgroundColor _col;
    _t ctrlCommit 0;
} forEach _panels;
_g
