/*
    CQ_fnc_storyUi  (client)
    [_speaker, _text] call CQ_fnc_storyUi;      _speaker: "CROSSROAD", "MAGPIE" or "COMHAT"
    One notification card per message, the same design for every speaker (modern, black /
    grey / white), docked on the left of the screen 50 px from the edge, the first card
    250 px from the top. A card is a horizontal block: speaker icon | speaker name + message.
    Several cards stack downward; when one expires the ones below slide up.
    MAGPIE reports can carry photos ([[id, class], ...], CQ_fnc_magPhoto): a grid of 128 px
    thumbnails (4 per row, vehicle name under each) under the text. Without Picture-in-Picture
    the vehicle's editor preview is shown instead.
    Settings: CQ_uiCardWidth (px), CQ_uiCardMax, CQ_magPhotoPx.
*/
params ["_who", "_txt", ["_photos", []]];
if (!hasInterface) exitWith {};
disableSerialization;

if (isNil "CQ_uiCards") then { CQ_uiCards = [] };
CQ_uiQueue = (missionNamespace getVariable ["CQ_uiQueue", []]) + [[_who, _txt, _photos]];
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
            _x params ["_ctrls", "_h", "_t", ["_extra", []]];
            _ctrls params ["_bg", "_iconBg", "_icon", "_txtC"];
            _bg ctrlSetPosition [_x0, _y, _w, _h];
            _iconBg ctrlSetPosition [_x0, _y, _ic, _h];
            _icon ctrlSetPosition [_x0 + (_ic - 26 * _px) / 2, _y + (_h - 26 * _py) / 2, 26 * _px, 26 * _py];
            _txtC ctrlSetPosition [_x0 + _ic + _pad, _y + 5 * _py, _w - _ic - 2 * _pad, _h - 8 * _py];
            {
                _x params ["_c", "_dx", "_dy", "_cw", "_chh"];
                _c ctrlSetPosition [_x0 + _ic + _pad + _dx, _y + _dy, _cw, _chh];
                _c ctrlCommit 0.2;
            } forEach _extra;
            { _x ctrlCommit 0.2 } forEach _ctrls;
            _y = _y + _h + _gap;
        } forEach CQ_uiCards;
    };

    while { true } do {
        // new messages -> new cards at the bottom of the stack
        while { (CQ_uiQueue isNotEqualTo []) && { count CQ_uiCards < CQ_uiCardMax } } do {
            (CQ_uiQueue deleteAt 0) params ["_who", "_txt", ["_photos", []]];
            private _bg = _d ctrlCreate ["RscText", -1];
            _bg ctrlSetBackgroundColor (CQ_ui get "panel");
            private _iconBg = _d ctrlCreate ["RscText", -1];
            _iconBg ctrlSetBackgroundColor (CQ_ui get "header");
            private _icon = _d ctrlCreate ["RscPicture", -1];
            _icon ctrlSetText (_icons getOrDefault [_who, _icons get "CROSSROAD"]);
            _icon ctrlSetTextColor (CQ_ui get "text");
            private _txtC = _d ctrlCreate ["RscStructuredText", -1];
            _txtC ctrlSetStructuredText parseText format [
                "<t font='PuristaSemibold' size='0.72' color='#A6A381'>%1</t><br/><t font='PuristaLight' size='0.88' color='#F2F1DF'>%2</t>",
                _who, if ((_txt select [0, 6]) == "<rich>") then { _txt select [6] } else { [_txt] call _esc }];
            // height from the wrapped text (min: the icon column)
            _txtC ctrlSetPosition [_x0 + _ic + _pad, -1, _w - _ic - 2 * _pad, 0.05];
            _txtC ctrlCommit 0;
            private _h = ((ctrlTextHeight _txtC) + 12 * _py) max (40 * _py);
            // photo grid under the text: [ctrl, dx, dy, w, h] relative to the text block
            private _extra = [];
            private _cams = [];
            if (_photos isNotEqualTo []) then {
                private _cell = CQ_magPhotoPx;                 // square thumbnail
                private _cw = round (_cell * CQ_magPhotoAspect); // the picture at the camera's own ratio, centre-cropped to the square
                private _cols = floor ((CQ_uiCardWidth - 60 + 6) / (_cell + 6)) max 1;   // as many as the text block holds
                private _g = 6;
                private _lab = 13;
                private _top = _h - 4 * _py;
                {
                    _x params ["_id", "_cls"];
                    private _cx = (_forEachIndex mod _cols) * (_cell + _g) * _px;
                    private _cy = _top + (floor (_forEachIndex / _cols)) * (_cell + _lab + _g) * _py;
                    private _frame = _d ctrlCreate ["RscText", -1];
                    _frame ctrlSetBackgroundColor (CQ_ui get "inset");
                    // square window (a controls group clips its children) over the wider picture
                    private _win = _d ctrlCreate ["RscControlsGroupNoScrollbars", -1];
                    private _pic = _d ctrlCreate ["RscPicture", -1, _win];
                    _pic ctrlSetPosition [-((_cw - _cell) / 2) * _px, 0, _cw * _px, _cell * _py];
                    _pic ctrlCommit 0;
                    private _cfg = configFile >> "CfgVehicles" >> _cls;
                    private _prev = getText (_cfg >> "editorPreview");
                    // live camera while the card is shown (CQ_fnc_magPhoto); none -> the editor preview
                    private _cam = ["start", [_id]] call CQ_fnc_magPhoto;
                    if (!isNull _cam) then { _cams pushBack _cam };
                    _pic ctrlSetText (if (!isNull _cam) then { format ["#(argb,%2,%2,1)r2t(cq_ph_%1,1.0)", _id mod CQ_magPhotoSlots, CQ_magPhotoPx] } else { [_prev, getText (_cfg >> "picture")] select (_prev == "") });
                    private _name = _d ctrlCreate ["RscText", -1];
                    _name ctrlSetText getText (_cfg >> "displayName");
                    _name ctrlSetFont "PuristaLight";
                    _name ctrlSetFontHeight (11 * _py);
                    _name ctrlSetTextColor [0.95, 0.94, 0.87, 1];
                    _extra pushBack [_frame, _cx - 1 * _px, _cy - 1 * _py, (_cell + 2) * _px, (_cell + 2) * _py];
                    _extra pushBack [_win, _cx, _cy, _cell * _px, _cell * _py];
                    _extra pushBack [_name, _cx, _cy + _cell * _py, _cell * _px, _lab * _py];
                } forEach _photos;
                private _rows = ceil ((count _photos) / _cols);
                _h = _top + _rows * (_cell + _lab + _g) * _py + 4 * _py;
            };
            private _ctrls = [_bg, _iconBg, _icon, _txtC];
            { _x ctrlSetFade 1; _x ctrlCommit 0 } forEach (_ctrls + (_extra apply { _x select 0 }));
            CQ_uiCards pushBack [_ctrls, _h, time + 6 + 0.05 * count _txt + 3 * count _photos, _extra, _cams];
            call _layout;
            { _x ctrlSetFade 0; _x ctrlCommit 0.25 } forEach (_ctrls + (_extra apply { _x select 0 }));
        };
        // expired cards fade out, the rest slide up
        private _old = CQ_uiCards select { time > (_x select 2) };
        if (_old isNotEqualTo []) then {
            { { _x ctrlSetFade 1; _x ctrlCommit 0.4 } forEach ((_x select 0) + ((_x param [3, []]) apply { _x select 0 })) } forEach _old;
            sleep 0.4;
            { { ctrlDelete _x } forEach ((_x select 0) + ((_x param [3, []]) apply { _x select 0 })) } forEach _old;
            { { ["stop", [_x]] call CQ_fnc_magPhoto } forEach (_x param [4, []]) } forEach _old;     // photo cameras off with their card
            CQ_uiCards = CQ_uiCards - _old;
            call _layout;
        };
        sleep 0.25;
    };
};
