/*
    CQ_fnc_uiSel  (client)
    [_button, _selected] call CQ_fnc_uiSel;
    Selected (current tab, main action): red background, light text. Otherwise the normal
    light grey button (light brown on hover, CQ_fnc_uiStyle).
*/
params ["_c", "_on"];
_c setVariable ["CQ_sel", _on];
private _bg = [CQ_ui get "button", CQ_ui get "buttonOn"] select _on;
_c setVariable ["CQ_base", _bg];
_c ctrlSetBackgroundColor _bg;
_c ctrlSetTextColor ([CQ_ui get "text", CQ_ui get "textOn"] select _on);
