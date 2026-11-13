/*
    SC_fnc_menu - the showcase menu: list of compositions (author, objects OK / total, plot),
    Teleport to its plot | Place in front of me | Remove placed near me | Export layout | Close.
*/
disableSerialization;
// (SQF names are case-insensitive: _X would be the loop's _x, hence _mX0 / _mY0 ...)
if (!isNull (uiNamespace getVariable ["SC_menu", displayNull])) exitWith {};
private _d = (findDisplay 46) createDisplay "RscDisplayEmpty";
uiNamespace setVariable ["SC_menu", _d];
private _mW0 = safeZoneW * 0.42; private _mH0 = safeZoneH * 0.6;
private _mX0 = safeZoneX + (safeZoneW - _mW0) / 2; private _mY0 = safeZoneY + (safeZoneH - _mH0) / 2;
private _mk = {
    params ["_cls", "_idc", "_pos", ["_txt", ""]];
    private _c = _d ctrlCreate [_cls, _idc];
    _c ctrlSetPosition _pos; if (_txt != "") then { _c ctrlSetText _txt }; _c ctrlCommit 0; _c
};
(["RscText", -1, [_mX0, _mY0, _mW0, _mH0]] call _mk) ctrlSetBackgroundColor [0.1, 0.11, 0.09, 0.94];
private _t = ["RscText", -1, [_mX0 + 0.01, _mY0 + 0.005, _mW0 - 0.02, 0.045], "COMPOSITION SHOWCASE  -  CntoDev compositions, CC-BY-SA-4.0"] call _mk;
_t ctrlSetTextColor [0.57, 0.55, 0.23, 1];
private _lb = ["RscListBox", 7100, [_mX0 + 0.01, _mY0 + 0.055, _mW0 - 0.02, _mH0 - 0.18]] call _mk;
{
    _x params ["_name", "_author"];
    (SC_report select _forEachIndex) params ["_ok", "_all", "_miss", "_dlc"];
    private _plot = (SC_plots select _forEachIndex) select 1;
    private _i = _lb lbAdd format ["%1. %2  (by %3)   %4/%5 objects%6%7", _forEachIndex + 1, _name, _author, _ok, _all,
        ["", format ["  | %1 mod", count _miss]] select (_miss isNotEqualTo []), ["", "  | no plot"] select (_plot isEqualTo [])];
    _lb lbSetValue [_i, _forEachIndex];
    if (_ok < _all) then { _lb lbSetColor [_i, [0.9, 0.75, 0.4, 1]] };
} forEach SC_comps;
_lb lbSetCurSel 0;
private _bw = (_mW0 - 0.06) / 5; private _by = _mY0 + _mH0 - 0.11;
{
    _x params ["_label", "_code", "_k"];
    private _b = ["RscButton", -1, [_mX0 + 0.01 + _k * (_bw + 0.01), _by, _bw, 0.05], _label] call _mk;
    _b setVariable ["code", _code];
    _b ctrlAddEventHandler ["ButtonClick", {
        params ["_b"];
        private _d = ctrlParent _b;
        private _i = (_d displayCtrl 7100) lbValue (lbCurSel (_d displayCtrl 7100));
        [_i, _d] call (_b getVariable "code");
    }];
} forEach [
    ["Teleport", { params ["_i", "_d"]; private _p = (SC_plots select _i) select 1;
        if (_p isEqualTo []) exitWith { hint "That composition has no plot" };
        player setPosATL ((_p getPos [((SC_plots select _i) select 4) + 6, ((SC_plots select _i) select 2) + 180]) vectorAdd [0, 0, 0]);
        player setDir (player getDir _p); _d closeDisplay 1 }, 0],
    ["Place here", { params ["_i", "_d"]; _d closeDisplay 1; ["start", _i] spawn SC_fnc_place }, 1],
    ["Remove near", { params ["", "_d"]; ["removeNear"] call SC_fnc_place }, 2],
    ["Export", { ["export"] call SC_fnc_place }, 3],
    ["Close", { params ["", "_d"]; _d closeDisplay 1 }, 4]
];
private _info = ["RscText", -1, [_mX0 + 0.01, _mY0 + _mH0 - 0.055, _mW0 - 0.02, 0.045],
    format ["%1 placed by you  |  Q / E turn while placing  |  map: blue flags = plots", count (missionNamespace getVariable ["SC_placed", []])]] call _mk;
_info ctrlSetTextColor [0.65, 0.64, 0.5, 1];
