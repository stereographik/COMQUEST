/*
    CQ_fnc_magReportUi  (client)   U twice quickly, or MAGPIE REPORT in the U menu
    The last MAGPIE report on the field tablet (same picture as squads / class / stats), three tabs:
      LAST SEEN         what that report identified (new since the one before) + its HQ news
      GLOBAL SITUATION  every enemy MAGPIE knows and still alive, at the time of that report
      NETWORK           health of the data link, current state, statistics, and a timeline with
                        one track per message category (CQ_mnetPub, CQ_fnc_netPub)
    Contacts by category (INFANTRY one row per squad, STATIC, LIGHT VEHICLES, ARMOUR, AIR):
      type | heading | speed | HQ owner | in sight (when the report was made)
    Header: age of the report and the countdown to the next one (CQ_magReportNextT); the LED on the
    tablet's top-left knob blinks blue for 3 s when a report or a new identification comes in while
    it is open (LAST SEEN = the last report's new contacts + those identified since).
    Data: CQ_magReportPub = [serverTime, [news...], [[cat, type, hdg, spd, owner, inSight, new], ...]]
    (CQ_fnc_magTick, with every report). Refreshes every 2 s while open. U or Esc closes it.
*/
if (!hasInterface) exitWith {};
disableSerialization;
private _open = uiNamespace getVariable ["CQ_mrDisplay", displayNull];
if (!isNull _open) exitWith { _open closeDisplay 1 };
{ if (!isNull (uiNamespace getVariable [_x, displayNull])) then { (uiNamespace getVariable _x) closeDisplay 1 } } forEach ["CQ_menuDisplay", "CQ_sqDisplay", "CQ_shopDisplay", "CQ_depotDisplay"];

private _d = (findDisplay 46) createDisplay "RscDisplayEmpty";
uiNamespace setVariable ["CQ_mrDisplay", _d];
_d displayAddEventHandler ["KeyDown", { params ["_d", "_k"]; if (_k == 22) then { _d closeDisplay 1; true } else { false } }];

// the field tablet, laid out like CQ_fnc_squadUi
private _ph = safeZoneH * CQ_sqSize;
private _pw = (_ph / pixelH) * 1.6 * pixelW;
if (_pw > safeZoneW) then { _ph = _ph * safeZoneW / _pw; _pw = safeZoneW };
private _picX = safeZoneX + (safeZoneW - _pw) / 2;
private _picY = safeZoneY + (safeZoneH - _ph) / 2;
CQ_sqScreen params ["_fx0", "_fy0", "_fx1", "_fy1"];
private _X = _picX + _pw * _fx0 + 0.004;
private _Y = _picY + _ph * _fy0 + 0.004;
private _W = _pw * (_fx1 - _fx0) - 0.008;
private _H = _ph * (_fy1 - _fy0) - 0.008;
private _L = (0.042 * _H / (safeZoneH * 0.66)) max 0.03;
private _mk = {
    params ["_cls", "_pos", ["_txt", ""]];
    private _c = _d ctrlCreate [[_cls, "CQ_Button"] select (_cls == "RscButton"), -1];
    [_c, _cls] call CQ_fnc_uiStyle;
    if !(_cls in ["RscPicture", "RscStructuredText"]) then { _c ctrlSetFontHeight ((ctrlFontHeight _c) * CQ_sqFont) };
    _c ctrlSetPosition _pos;
    if (_txt != "") then { _c ctrlSetText _txt };
    _c ctrlCommit 0;
    _c
};
// the tablet picture is the window's first control (under everything else, and above the map when
// the map is open: a title layer is drawn under the map); the same picture on a title layer stays
// as a fallback under it
private _picW = _d ctrlCreate ["RscPicture", -1];
_picW ctrlSetPosition [_picX, _picY, _pw, _ph];
_picW ctrlCommit 0;
_picW ctrlSetText (getMissionPath "media\comtablet_ca.paa");
"CQ_mrBg" cutRsc ["RscTitleDisplayEmpty", "PLAIN", 0, false];
private _bg = uiNamespace getVariable ["RscTitleDisplayEmpty", displayNull];
private _pic = _bg ctrlCreate ["RscPicture", -1];
_pic ctrlSetPosition [_picX, _picY, _pw, _ph];
_pic ctrlCommit 0;
_pic ctrlSetText (getMissionPath "media\comtablet_ca.paa");
_d displayAddEventHandler ["Unload", { "CQ_mrBg" cutText ["", "PLAIN"] }];

(["RscText", [_X, _Y, _W, _H]] call _mk) ctrlSetBackgroundColor [0.02, 0.03, 0.02, CQ_mrTint];   // darker than the other windows: dense table
(["RscText", [_X, _Y, _W, _L * 1.1]] call _mk) ctrlSetBackgroundColor (CQ_ui get "header");
private _tabL = ["RscButton", [_X + 0.01, _Y + 0.004, _W * 0.22, _L], "LAST SEEN"] call _mk;
private _tabG = ["RscButton", [_X + 0.02 + _W * 0.22, _Y + 0.004, _W * 0.3, _L], "GLOBAL SITUATION"] call _mk;
private _tabN = ["RscButton", [_X + 0.03 + _W * 0.52, _Y + 0.004, _W * 0.2, _L], "NETWORK"] call _mk;
_tabN ctrlAddEventHandler ["ButtonClick", { uiNamespace setVariable ["CQ_mrTab", "network"]; uiNamespace setVariable ["CQ_mrDirty", true] }];
uiNamespace setVariable ["CQ_mrTabN", _tabN];
uiNamespace setVariable ["CQ_mrTab", uiNamespace getVariable ["CQ_mrTab", "last"]];
_tabL ctrlAddEventHandler ["ButtonClick", { uiNamespace setVariable ["CQ_mrTab", "last"]; uiNamespace setVariable ["CQ_mrDirty", true] }];
_tabG ctrlAddEventHandler ["ButtonClick", { uiNamespace setVariable ["CQ_mrTab", "global"]; uiNamespace setVariable ["CQ_mrDirty", true] }];
private _close = ["RscButton", [_X + _W - 0.05, _Y + 0.004, 0.04, _L], "X"] call _mk;
_close ctrlAddEventHandler ["ButtonClick", { (uiNamespace getVariable ["CQ_mrDisplay", displayNull]) closeDisplay 1 }];

// the small LED on top of the tablet's top-left knob (CQ_mrLed: [x, y, size] as fractions of the
// picture width / height / width): blinks blue for 3 s when a new report arrives while the window is open
CQ_mrLed params ["_lx", "_lyy", "_ls"];
private _lw = _pw * _ls;                         // width (screen units)
private _lh = _lw * (pixelH / pixelW);           // same size in pixels: a round dot
private _led = ["RscPicture", [_picX + _pw * _lx - _lw / 2, _picY + _ph * _lyy - _lh / 2, _lw, _lh]] call _mk;
_led ctrlSetText "\A3\ui_f\data\map\markers\military\dot_CA.paa";
_led ctrlSetTextColor [0.25, 0.55, 1, 1];
_led ctrlShow false;
private _top = _Y + _L * 1.5;
private _info = ["RscStructuredText", [_X + 0.01, _top, _W - 0.02, _L * 2.6]] call _mk;
private _ly = _top + _L * 2.8;
private _list = ["RscListNBox", [_X + 0.01, _ly, _W - 0.02, _H - (_ly - _Y) - 0.01]] call _mk;
// ---- NETWORK tab: health chips, state, stats (one text), then the timeline: one track per
// message category, the track heights shared so all of them always fit, a pin per message
// (same category within CQ_netMerge s: one pin with a count), the playhead at "now", and the
// latest message under it
private _netTxt = ["RscStructuredText", [_X + 0.01, _top, _W - 0.02, _L * 4.4]] call _mk;
private _tlY = _top + _L * 4.6;
private _tlH = _H - (_tlY - _Y) - _L * 2.2;
private _lw = _W * 0.13;
private _laneX = _X + 0.01 + _lw;
private _laneW = _W - 0.02 - _lw;
private _netCtrls = [_netTxt];
private _bgT = ["RscText", [_X + 0.01, _tlY, _W - 0.02, _tlH]] call _mk;
_bgT ctrlSetBackgroundColor [0.06, 0.1, 0.07, 1];
_netCtrls pushBack _bgT;
private _tracks = [["REPORT", "report", [0.22, 0.54, 0.87, 1]], ["CONTACT", "contact", [0.94, 0.62, 0.15, 1]], ["MEMORY", "memory", [0.5, 0.47, 0.87, 1]], ["LINK", "link", [0.89, 0.29, 0.29, 1]], ["LOSS", "loss", [0.71, 0.7, 0.66, 1]]];
private _th = _tlH / count _tracks;
private _leftX = _X;   // _X is _x inside forEach (names ignore case): keep it under another name
{
    _x params ["_lbl", "", "_col"];
    private _t = ["RscText", [_leftX + 0.012, _tlY + _forEachIndex * _th, _lw - 0.004, _th], _lbl] call _mk;
    _t ctrlSetTextColor _col;
    _netCtrls pushBack _t;
    if (_forEachIndex > 0) then {
        private _sep = ["RscText", [_laneX, _tlY + _forEachIndex * _th, _laneW, pixelH]] call _mk;
        _sep ctrlSetBackgroundColor [0.23, 0.29, 0.24, 1];
        _netCtrls pushBack _sep;
    };
} forEach _tracks;
private _lane0 = ["RscText", [_laneX, _tlY, pixelW, _tlH]] call _mk;
_lane0 ctrlSetBackgroundColor [0.23, 0.29, 0.24, 1];
private _play = ["RscText", [_laneX + _laneW - 2 * pixelW, _tlY, pixelW * 2, _tlH]] call _mk;
_play ctrlSetBackgroundColor [0.95, 0.95, 0.87, 1];
_netCtrls append [_lane0, _play];
private _axis = ["RscStructuredText", [_laneX - 0.02, _tlY + _tlH, _laneW + 0.03, _L]] call _mk;
_axis ctrlSetStructuredText parseText format ["<t size='0.75' color='#888780'>-%1 min<t align='center'>-%2 min</t><t align='right'>now</t></t>", round (CQ_netSpan / 60), round (CQ_netSpan / 120)];
private _lastMsg = ["RscStructuredText", [_X + 0.01, _tlY + _tlH + _L, _W - 0.02, _L * 1.1]] call _mk;
_netCtrls append [_axis, _lastMsg];
uiNamespace setVariable ["CQ_mrNet", [_netCtrls, _netTxt, _lastMsg, [_laneX, _laneW, _tlY, _th], _tracks]];
// draws the NETWORK tab from CQ_mnetPub (pins rebuilt each time)
CQ_mrDrawNet = {
    params ["_d"];
    disableSerialization;
    (uiNamespace getVariable ["CQ_mrNet", []]) params ["", "_netTxt", "_lastMsg", "_geo", "_tracks"];
    _geo params ["_laneX", "_laneW", "_tlY", "_th"];
    (missionNamespace getVariable ["CQ_mnetPub", []]) params [["_ev", []], ["_hl", ["OK", 0, 0, [], "-"]], ["_st", ["", ""]], ["_ss", [0, 0, 0, 0]]];
    _hl params ["_link", "_nl", "_nn", "_drones", "_rvTxt"];
    private _lc = ["#C0DD97", "#FAC775", "#F09595"] select ((["OK", "DEGRADED", "CUT"] find _link) max 0);
    private _dr = (_drones apply { format ["%1 %2", _x select 0, ["<t color='#F09595'>" + (_x select 1) + "</t>", "&#10003;"] select ((_x select 1) == "up")] }) joinString "  ·  ";
    private _txt = format ["<t size='0.9'><t color='%1'>LINK %2</t>   <t color='#E8E6D9'>NODES %3/%4</t>   <t color='#E8E6D9'>%5</t>   <t color='#FAC775'>RELAY VEHICLE %6</t></t>", _lc, _link, _nl, _nn, _dr, _rvTxt];
    _txt = _txt + format ["<br/><t size='0.95' color='#F2F1DF'>%1</t><br/><t size='0.85' color='#B4B2A9'>%2</t>", _st select 0, _st select 1];
    _txt = _txt + format ["<br/><t size='0.85' color='#B4B2A9'>contacts </t><t size='0.95' color='#F2F1DF'>%1</t><t size='0.85' color='#B4B2A9'>     reports </t><t size='0.95' color='#F2F1DF'>%2</t><t size='0.85' color='#B4B2A9'>     drones lost </t><t size='0.95' color='#F2F1DF'>%3</t><t size='0.85' color='#B4B2A9'>     link uptime </t><t size='0.95' color='#F2F1DF'>%4%%</t>", _ss select 0, _ss select 1, _ss select 2, _ss select 3];
    _netTxt ctrlSetStructuredText parseText _txt;
    // pins
    { ctrlDelete _x } forEach (uiNamespace getVariable ["CQ_mrPins", []]);
    private _pins = [];
    private _now = serverTime;
    {
        _x params ["", "_cat", "_col"];
        private _ti = _forEachIndex;
        private _evs = _ev select { (_x select 1) == _cat && { _now - (_x select 0) < CQ_netSpan } };
        // merge the ones within CQ_netMerge s of each other
        private _grp = [];
        { private _e = _x; private _gi = _grp findIf { abs ((_x select 0) - (_e select 0)) < CQ_netMerge }; if (_gi < 0) then { _grp pushBack [_e select 0, _e param [3, 1]] } else { (_grp select _gi) set [1, ((_grp select _gi) select 1) + (_e param [3, 1])] } } forEach _evs;
        {
            _x params ["_t", "_n"];
            private _px = [9, 16] select (_n > 1);
            private _pinW = _px * pixelW; private _pinH = _px * pixelH;
            private _cx = _laneX + _laneW * (1 - (_now - _t) / CQ_netSpan);
            private _cy = _tlY + _th * (_ti + 0.5);
            private _p = _d ctrlCreate ["RscStructuredText", -1];
            _p ctrlSetPosition [_cx - _pinW / 2, _cy - _pinH / 2, _pinW, _pinH];
            _p ctrlSetBackgroundColor _col;
            if (_n > 1) then { _p ctrlSetStructuredText parseText format ["<t align='center' size='0.7' color='#101A12'>%1</t>", _n] };
            _p ctrlCommit 0;
            _pins pushBack _p;
        } forEach _grp;
    } forEach _tracks;
    uiNamespace setVariable ["CQ_mrPins", _pins];
    // latest message
    if (_ev isNotEqualTo []) then {
        private _e = _ev select (count _ev - 1);
        private _ci = _tracks findIf { (_x select 1) == (_e select 1) };
        private _hex = ["#378ADD", "#EF9F27", "#7F77DD", "#E24B4A", "#B4B2A9"] select (_ci max 0);
        private _ago = round ((_now - (_e select 0)) / 60);
        _lastMsg ctrlSetStructuredText parseText format ["<t size='0.85'><t color='%1'>&#9679; </t><t color='#F2F1DF'>%2 min ago  %3 · %4</t></t>", _hex, _ago, toUpper (_e select 1), _e select 2];
    } else { _lastMsg ctrlSetStructuredText parseText "<t size='0.85' color='#B4B2A9'>No message on the network yet.</t>" };
};
_list lnbSetColumnsPos [0, 0.42, 0.54, 0.66, 0.88];

// header text: which tab, age of the report, contacts, countdown to the next one, HQ news (LAST SEEN)
// (redrawn every second for the countdown; the list itself only on a new report or another tab)
CQ_mrSetInfo = {
    params ["_info"];
    (missionNamespace getVariable ["CQ_magReportPub", []]) params [["_t", -1], ["_news", []], ["_rows", []]];
    private _last = (uiNamespace getVariable ["CQ_mrTab", "last"]) == "last";
    private _next = (missionNamespace getVariable ["CQ_magReportNextT", -1]) - serverTime;
    private _cd = if (_next < 0) then { "soon" } else { format ["%1:%2", floor (_next / 60), [str (floor (_next mod 60)), "0" + str (floor (_next mod 60))] select ((floor (_next mod 60)) < 10)] };
    if (_t < 0) exitWith {
        _info ctrlSetStructuredText parseText format ["<t size='0.9' color='#F2F1DF'>No MAGPIE report yet.  ·  Next check in %1</t>", _cd];
    };
    private _n = if (_last) then { { _x param [6, false] } count _rows } else { count _rows };
    private _txt = format ["<t size='0.9' color='#F2F1DF'>%1  ·  report of %2 min ago  ·  %3 contacts</t><t size='0.9' color='#7FB2FF'>  ·  next report in %4 (if anything new)</t>",
        ["Every enemy MAGPIE knows", "New since the report before"] select _last, round ((serverTime - _t) / 60), _n, _cd];
    if (_last) then {
        { _txt = _txt + format ["<br/><t size='0.85' color='#F2F1DF'>%1</t>", _x] } forEach (_news select [0, 2]);
        if (count _news > 2) then { _txt = _txt + format ["<br/><t size='0.8' color='#F2F1DF'>+%1 more HQ news</t>", count _news - 2] };
    };
    _info ctrlSetStructuredText parseText _txt;
};
private _fill = {
    params ["_info", "_list", "_tabL", "_tabG"];
    (missionNamespace getVariable ["CQ_magReportPub", []]) params [["_t", -1], ["_news", []], ["_rows", []]];
    private _tab = uiNamespace getVariable ["CQ_mrTab", "last"];
    private _last = _tab == "last";
    // active tab highlighted
    _tabL ctrlSetBackgroundColor (CQ_ui get (["button", "buttonOn"] select (_tab == "last")));
    _tabG ctrlSetBackgroundColor (CQ_ui get (["button", "buttonOn"] select (_tab == "global")));
    (uiNamespace getVariable ["CQ_mrTabN", controlNull]) ctrlSetBackgroundColor (CQ_ui get (["button", "buttonOn"] select (_tab == "network")));
    // NETWORK tab: its own controls instead of the list
    private _net = _tab == "network";
    { _x ctrlShow _net } forEach ((uiNamespace getVariable ["CQ_mrNet", [[]]]) select 0);
    _info ctrlShow !_net; _list ctrlShow !_net;
    if (_net) exitWith { [ctrlParent _info] call CQ_mrDrawNet };
    { ctrlDelete _x } forEach (uiNamespace getVariable ["CQ_mrPins", []]); uiNamespace setVariable ["CQ_mrPins", []];
    lnbClear _list;
    [_info] call CQ_mrSetInfo;
    if (_t < 0) exitWith {};
    if (_last) then { _rows = _rows select { _x param [6, false] } };
    private _muted = [0.85, 0.84, 0.7, 1];   // column titles
    private _r = _list lnbAddRow ["CONTACT", "HDG", "SPD", "HQ", "IN SIGHT"];
    for "_c" from 0 to 4 do { _list lnbSetColor [[_r, _c], _muted] };
    {
        _x params ["_cat", "_name"];
        private _sel = _rows select { (_x select 0) == _cat };
        if (_sel isEqualTo []) then { continue };
        _r = _list lnbAddRow [format ["%1 (%2)", _name, count _sel], "", "", "", ""];
        _list lnbSetColor [[_r, 0], [1, 0.78, 0.3, 1]];   // category: bright amber
        {
            _x params ["", ["_type", "?"], ["_hdg", 0], ["_spd", 0], ["_own", "-"], ["_vis", false], ["_isNew", false]];
            if (isNil "_own" || { !(_own isEqualType "") }) then { _own = "-" };
            private _hx = str (round _hdg);
            while { count _hx < 3 } do { _hx = "0" + _hx };
            _r = _list lnbAddRow ["   " + _type, _hx, format ["%1 km/h", round _spd], _own, ["no", "YES"] select _vis];
            for "_c" from 0 to 3 do { _list lnbSetColor [[_r, _c], [0.95, 0.95, 0.9, 1]] };
            _list lnbSetColor [[_r, 4], [[0.75, 0.75, 0.7, 1], [1, 0.35, 0.3, 1]] select _vis];
        } forEach _sel;
    } forEach [["inf", "INFANTRY"], ["static", "STATIC"], ["light", "LIGHT VEHICLES"], ["armour", "ARMOUR"], ["air", "AIR"]];
};
[_info, _list, _tabL, _tabG] call _fill;
[_d, _info, _list, _tabL, _tabG, _fill, _led] spawn {
    params ["_d", "_info", "_list", "_tabL", "_tabG", "_fill", "_led"];
    disableSerialization;
    private _last = (missionNamespace getVariable ["CQ_magReportPub", []]) param [3, -1];
    private _sec = 0;
    private _netSec = 0;
    uiNamespace setVariable ["CQ_mrDirty", false];
    while { !isNull _d } do {
        sleep 0.2;
        if (isNull _d) exitWith {};
        private _t = (missionNamespace getVariable ["CQ_magReportPub", []]) param [3, -1];
        // a new report or a new identification: redraw and blink the LED blue for 3 s
        if (_t != _last) then {
            _last = _t;
            [_info, _list, _tabL, _tabG] call _fill;
            _led spawn {
                disableSerialization;
                for "_i" from 1 to 12 do { if (isNull _this) exitWith {}; _this ctrlShow (_i mod 2 == 1); sleep 0.25 };
                if (!isNull _this) then { _this ctrlShow false };
            };
        };
        // another tab: redraw (the list keeps its place otherwise)
        if (uiNamespace getVariable ["CQ_mrDirty", false]) then {
            uiNamespace setVariable ["CQ_mrDirty", false];
            [_info, _list, _tabL, _tabG] call _fill;
        };
        // countdown, every second
        _sec = _sec + 0.2;
        if (_sec >= 1) then {
            _sec = 0;
            if ((uiNamespace getVariable ["CQ_mrTab", "last"]) == "network") then {
                _netSec = _netSec + 1;
                if (_netSec >= 2) then { _netSec = 0; [_d] call CQ_mrDrawNet };
            } else { [_info] call CQ_mrSetInfo };
        };
    };
};
