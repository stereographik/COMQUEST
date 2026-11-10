/*
    CQ_fnc_uiStyle  (client)
    [_ctrl, _class] call CQ_fnc_uiStyle;
    Gives a freshly created control the mission's look (CQ_ui): Purista everywhere, pale cyan
    text, teal buttons. Windows still set their own panel / header backgrounds from CQ_ui.
*/
params ["_c", "_cls"];
if (_cls == "RscPicture") exitWith {};
_c ctrlSetFont (CQ_ui get "font");
_c ctrlSetTextColor (CQ_ui get "text");
if (_cls in ["RscButton", "RscButtonMenu", "RscShortcutButton"]) then {
    _c ctrlSetBackgroundColor (CQ_ui get "button");
    _c ctrlSetActiveColor (CQ_ui get "buttonActive");
};
