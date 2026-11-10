/*
    CQ_fnc_storyUi  (client)
    [_speaker, _text] call CQ_fnc_storyUi;      _speaker: "CROSSROAD", "MAGPIE" or "COMHAT"
    One notification card per message, the same design for every speaker (modern, black /
    grey / white), docked on the left of the screen 50 px from the edge, the first card
    250 px from the top. A card is a horizontal block: speaker icon | speaker name + message.
    Several cards stack downward; when one expires the ones below slide up.
    Settings: CQ_uiCardWidth (px), CQ_uiCardMax.
*/
params ["_who", "_txt"];
if (!hasInterface) exitWith {};
disableSerialization;

if (isNil "CQ_uiCards") then { CQ_uiCards = [] };
CQ_uiQueue = (missionNamespace getVariable ["CQ_uiQueue", []]) + [[_who, _txt]];
if (!isNil "CQ_uiLoop") exitWith {};
CQ_uiLoop = true;

[] spawn {
    disableSerialization;
    waitUntil { !isNull findDisplay 46 };
    private _d = findDisplay 46;
    private _px = pixelW;
    private _py = pixelH;
    private _x0 = safezoneX + 50 * _px;
    private _y0 = safezoneY + 250 * _py;
    private _w = CQ_uiCardWidth * _px;
    private _ic = 44 * _px;                     // icon column
    private _gap = 6 * _py;
    private _pad = 8 * _px;
    private _icons = createHashMapFromArray [
        ["CROSSROAD", "\A3\ui_f\data\igui\cfg\simpleTasks\types\radio_ca.paa"],
        ["MAGPIE", "\A3\ui_f\data\igui\cfg\simpleTasks\types\scout_ca.paa"],
        ["COMHAT", "\A3\ui_f\data\igui\cfg\simpleTasks\types\listen_ca.paa"]
    ];
    private _esc = { params ["_s"]; ((_s splitString "&") joinString "&amp;") splitString "<" joinString "&lt;" };

    // re-place every card under the previous one (animated)
    private _layout = {
        private _y = _y0;
        {
            _x params ["_ctrls", "_h"];
            _ctrls params ["_bg", "_iconBg", "_icon", "_txtC"];
            _bg ctrlSetPosition [_x0, _y, _w, _h];
            _iconBg ctrlSetPosition [_x0, _y, _ic, _h];
            _icon ctrlSetPosition [_x0 + (_ic - 26 * _px) / 2, _y + (_h - 26 * _py) / 2, 26 * _px, 26 * _py];
            _txtC ctrlSetPosition [_x0 + _ic + _pad, _y + 5 * _py, _w - _ic - 2 * _pad, _h - 8 * _py];
            { _x ctrlCommit 0.2 } forEach _ctrls;
            _y = _y + _h + _gap;
        } forEach CQ_uiCards;
    };

    while { true } do {
        // new messages -> new cards at the bottom of the stack
        while { (CQ_uiQueue isNotEqualTo []) && { count CQ_uiCards < CQ_uiCardMax } } do {
            (CQ_uiQueue deleteAt 0) params ["_who", "_txt"];
            private _bg = _d ctrlCreate ["RscText", -1];
            _bg ctrlSetBackgroundColor (CQ_ui get "panel");
            private _iconBg = _d ctrlCreate ["RscText", -1];
            _iconBg ctrlSetBackgroundColor (CQ_ui get "header");
            private _icon = _d ctrlCreate ["RscPicture", -1];
            _icon ctrlSetText (_icons getOrDefault [_who, _icons get "CROSSROAD"]);
            _icon ctrlSetTextColor (CQ_ui get "text");
            private _txtC = _d ctrlCreate ["RscStructuredText", -1];
            _txtC ctrlSetStructuredText parseText format [
                "<t font='PuristaSemibold' size='0.72' color='#8CB7BD'>%1</t><br/><t font='PuristaLight' size='0.88' color='#D9F7FF'>%2</t>",
                _who, if ((_txt select [0, 6]) == "<rich>") then { _txt select [6] } else { [_txt] call _esc }];
            // height from the wrapped text (min: the icon column)
            _txtC ctrlSetPosition [_x0 + _ic + _pad, -1, _w - _ic - 2 * _pad, 0.05];
            _txtC ctrlCommit 0;
            private _h = ((ctrlTextHeight _txtC) + 12 * _py) max (40 * _py);
            private _ctrls = [_bg, _iconBg, _icon, _txtC];
            { _x ctrlSetFade 1; _x ctrlCommit 0 } forEach _ctrls;
            CQ_uiCards pushBack [_ctrls, _h, time + 6 + 0.05 * count _txt];
            call _layout;
            { _x ctrlSetFade 0; _x ctrlCommit 0.25 } forEach _ctrls;
        };
        // expired cards fade out, the rest slide up
        private _old = CQ_uiCards select { time > (_x select 2) };
        if (_old isNotEqualTo []) then {
            { { _x ctrlSetFade 1; _x ctrlCommit 0.4 } forEach (_x select 0) } forEach _old;
            sleep 0.4;
            { { ctrlDelete _x } forEach (_x select 0) } forEach _old;
            CQ_uiCards = CQ_uiCards - _old;
            call _layout;
        };
        sleep 0.25;
    };
};
