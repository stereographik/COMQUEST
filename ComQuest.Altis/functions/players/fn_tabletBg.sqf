/*
    CQ_fnc_tabletBg  (client)
    [_d, [_picX, _picY, _pw, _ph], [[[x, y, w, h], colour], ...]] call CQ_fnc_tabletBg;
    The field tablet's background (picture media\comtablet_l/r_ca.paa + the given panels, screen
    positions) inside one full-screen controls group, created first on the window. Plain controls
    created first were not drawn over the open map (the later ones were); a controls group keeps
    them at the back and drawn (BI forums, "CtrlCreate draw order"). Returns the group.
*/
params ["_d", "_pic", ["_panels", []]];
disableSerialization;
_pic params ["_px", "_py", "_pw", "_ph"];
// the picture in two square halves (media\comtablet_l_ca.paa, comtablet_r_ca.paa, 1024 x 1024):
// the 2048 x 1024 texture never drew on a window (only on a title layer), the square 1024 x 1024
// transceiver picture of the U menu does
{
    _x params ["_file", "_dx"];
    private _p = _d ctrlCreate ["RscPicture", -1];                       // on the window itself, like the U menu's picture
    _p ctrlSetPosition [_px + _dx, _py, _pw / 2 + pixelW, _ph];        // 1 px overlap at the seam
    _p ctrlCommit 0;
    _p ctrlSetText (getMissionPath format ["media\%1", _file]);
} forEach [["comtablet_l_ca.paa", 0], ["comtablet_r_ca.paa", _pw / 2]];
// the panels: in one full-screen controls group (drawn at the back)
private _g = _d ctrlCreate ["RscControlsGroupNoScrollbars", -1];
_g ctrlSetPosition [safeZoneX, safeZoneY, safeZoneW, safeZoneH];
_g ctrlCommit 0;
{
    _x params ["_r", "_col"];
    private _t = _d ctrlCreate ["RscText", -1, _g];
    _t ctrlSetPosition [(_r select 0) - safeZoneX, (_r select 1) - safeZoneY, _r select 2, _r select 3];
    _t ctrlSetBackgroundColor _col;
    _t ctrlCommit 0;
} forEach _panels;
_g
