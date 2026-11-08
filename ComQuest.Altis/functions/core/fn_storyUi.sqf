/*
    CQ_fnc_storyUi  (client)
    [_panel, _text] call CQ_fnc_storyUi;
    Draws the story panels on the game screen (vanilla controls created on display 46):
      "CROSSROAD"  wide panel top right, title + full text wrapped, height fits the text
      "MAGPIE"     panel bottom centre, monospace text typed out like a typewriter
    Each panel has its own queue: messages never cover each other or get cut.
*/
params ["_panel", "_txt"];
if (!hasInterface) exitWith {};

private _qk = format ["CQ_uiQ_%1", _panel];
private _q = missionNamespace getVariable [_qk, []];
_q pushBack _txt;
missionNamespace setVariable [_qk, _q];
if (missionNamespace getVariable [format ["CQ_uiBusy_%1", _panel], false]) exitWith {};
missionNamespace setVariable [format ["CQ_uiBusy_%1", _panel], true];

[_panel, _qk] spawn {
    params ["_panel", "_qk"];
    waitUntil { !isNull findDisplay 46 };
    private _d = findDisplay 46;
    private _esc = { params ["_s"]; ((_s splitString "&") joinString "&amp;") splitString "<" joinString "&lt;" };
    private _crossroad = _panel == "CROSSROAD";

    // geometry
    private _w = [0.5 * safezoneW, 0.34 * safezoneW] select _crossroad;
    private _px = [safezoneX + (safezoneW - _w) / 2, safezoneX + safezoneW - _w - 0.012 * safezoneW] select _crossroad;
    private _py = [safezoneY + 0.74 * safezoneH, safezoneY + 0.1 * safezoneH] select _crossroad;
    private _pad = 0.008 * safezoneW;
    private _sz = [1.05, 1] select _crossroad;   // text size factor

    while { count (missionNamespace getVariable [_qk, []]) > 0 } do {
        private _q = missionNamespace getVariable [_qk, []];
        private _txt = [_q deleteAt 0] call _esc;
        missionNamespace setVariable [_qk, _q];

        private _bg = _d ctrlCreate ["RscText", -1];
        private _bar = _d ctrlCreate ["RscText", -1];
        private _st = _d ctrlCreate ["RscStructuredText", -1];
        _bg ctrlSetBackgroundColor [0.02, 0.03, 0.02, 0.72];
        _bar ctrlSetBackgroundColor ([[0.85, 0.75, 0.35, 0.9], [0.45, 0.8, 0.4, 0.95]] select _crossroad);

        private _title = if (_crossroad) then { "<t font='PuristaBold' color='#7fd36b' size='1.0'>CROSSROAD</t><br/>" } else { "<t font='EtelkaMonospaceProBold' color='#e3cf7a' size='0.9'>MAGPIE &gt;</t> " };
        private _body = {
            params ["_s", ["_cursor", ""]];
            if (_crossroad) then {
                format ["%1<t font='PuristaMedium' color='#f0f0e8' size='%3'>%2</t>", _title, _s, _sz]
            } else {
                format ["%1<t font='EtelkaMonospacePro' color='#e8e4d0' size='%3'>%2%4</t>", _title, _s, _sz * 0.9, _cursor]
            };
        };

        // size the panel on the full text first, so typing does not make it jump
        _st ctrlSetPosition [_px + _pad * 1.6, _py + _pad, _w - _pad * 2.6, 0.05];
        _st ctrlSetStructuredText parseText ([_txt, "_"] call _body);
        _st ctrlCommit 0;
        private _h = (ctrlTextHeight _st) + 0.004;
        _st ctrlSetPosition [_px + _pad * 1.6, _py + _pad, _w - _pad * 2.6, _h];
        _bg ctrlSetPosition [_px, _py, _w, _h + _pad * 2];
        _bar ctrlSetPosition [_px, _py, 0.0025 * safezoneW, _h + _pad * 2];
        { _x ctrlSetFade 1; _x ctrlCommit 0; _x ctrlSetFade 0; _x ctrlCommit 0.25 } forEach [_bg, _bar, _st];

        if (_crossroad) then {
            sleep (6 + 0.045 * count _txt);
        } else {
            // typewriter: a few characters at a time, blinking cursor at the end
            private _chars = _txt splitString "";
            private _shown = "";
            {
                _shown = _shown + _x;
                if (_forEachIndex % 2 == 0 || { _forEachIndex == count _chars - 1 }) then {
                    _st ctrlSetStructuredText parseText ([_shown, "_"] call _body);
                    sleep 0.035;
                };
            } forEach _chars;
            for "_i" from 1 to 6 do {
                _st ctrlSetStructuredText parseText ([_shown, ["", "_"] select (_i % 2 == 0)] call _body);
                sleep 0.45;
            };
            sleep (2 + 0.02 * count _txt);
        };

        { _x ctrlSetFade 1; _x ctrlCommit 0.8 } forEach [_bg, _bar, _st];
        sleep 0.8;
        { ctrlDelete _x } forEach [_bg, _bar, _st];
        sleep 0.3;
    };
    missionNamespace setVariable [format ["CQ_uiBusy_%1", _panel], false];
};
