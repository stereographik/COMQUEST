/*
    CQ_fnc_uiStyle  (client)
    [_ctrl, _class] call CQ_fnc_uiStyle;
    Gives a freshly created control the mission's look (CQ_ui, dark theme): Purista, cream text,
    lists on a dark inset. Buttons are created as CQ_Button (description.ext): their hover,
    focus and press colours come from that class and always match; CQ_fnc_uiSel marks one
    as selected (red). Windows set their own panel / header backgrounds from CQ_ui.
*/
params ["_c", "_cls"];
if (_cls == "RscPicture") exitWith {};
_c ctrlSetFont (CQ_ui get "font");
_c ctrlSetTextColor (CQ_ui get "text");
if (_cls in ["RscListBox", "RscListNBox", "RscCombo", "RscEdit"]) then {
    _c ctrlSetBackgroundColor (CQ_ui get "inset");
};
