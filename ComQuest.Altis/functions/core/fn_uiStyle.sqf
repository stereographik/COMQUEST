/*
    CQ_fnc_uiStyle  (client)
    [_ctrl, _class] call CQ_fnc_uiStyle;
    Gives a freshly created control the mission's look (CQ_ui, light theme): Purista, dark text,
    buttons light grey -> light brown on hover -> red when selected (CQ_fnc_uiSel), lists on a
    light brown tint. Windows set their own panel / header backgrounds from CQ_ui.
*/
params ["_c", "_cls"];
if (_cls == "RscPicture") exitWith {};
_c ctrlSetFont (CQ_ui get "font");
_c ctrlSetTextColor (CQ_ui get "text");
if (_cls in ["RscButton", "RscButtonMenu", "RscShortcutButton"]) then {
    _c ctrlSetBackgroundColor (CQ_ui get "button");
    _c ctrlSetActiveColor (CQ_ui get "buttonActive");
    _c setVariable ["CQ_base", CQ_ui get "button"];
    _c ctrlAddEventHandler ["MouseEnter", { params ["_c"]; if !(_c getVariable ["CQ_sel", false]) then { _c ctrlSetBackgroundColor (CQ_ui get "buttonHover") } }];
    _c ctrlAddEventHandler ["MouseExit", { params ["_c"]; _c ctrlSetBackgroundColor (_c getVariable ["CQ_base", CQ_ui get "button"]) }];
};
if (_cls in ["RscListBox", "RscListNBox", "RscCombo", "RscEdit"]) then {
    _c ctrlSetBackgroundColor (CQ_ui get "inset");
};
