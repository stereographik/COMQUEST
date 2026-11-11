/*
    CQ_fnc_storyClient  (client, from CQ_fnc_say through remoteExec)
    [_speaker, _text] call CQ_fnc_storyClient;
      All three speakers: the same notification card (CQ_fnc_storyUi), stacked on the left;
      CROSSROAD also in Side chat, the others in the chat log.
    Every line also goes to the "Radio log" page of the map so it can be read again.
*/
params ["_who", "_txt"];
if (!hasInterface) exitWith {};
// MAGPIE's icon report carries structured text ("<rich>" marker): plain copy for chat / log
// replace every _a by _b (search resumes after each replacement)
private _rep = {
    params ["_s", "_a", "_b"];
    private _out = "";
    private _i = _s find _a;
    while { _i > -1 } do {
        _out = _out + (_s select [0, _i]) + _b;
        _s = _s select [_i + count _a];
        _i = _s find _a;
    };
    _out + _s
};
// MAGPIE's photo grid: "<ph>id:class,...</ph>" taken out of the text, given to the card
private _photos = [];
private _pa = _txt find "<ph>";
if (_pa > -1) then {
    private _pb = _txt find "</ph>";
    _photos = ((_txt select [_pa + 4, _pb - _pa - 4]) splitString ",") apply { private _p = _x splitString ":"; [parseNumber (_p select 0), _p select 1] };
    _txt = (_txt select [0, _pa]) + (_txt select [_pb + 5]);
};
private _rich = _txt find "<rich>" > -1;
_txt = [_txt, "<rich>", ""] call _rep;
private _plain = _txt;
if (_rich) then {
    _plain = [_plain, "<br/>", " | "] call _rep;
    { _plain = [_plain, _x select 0, _x select 1] call _rep } forEach [
        ["iconMan_ca.paa'/>", "iconMan_ca.paa'/>inf "], ["iconCar_ca.paa'/>", "iconCar_ca.paa'/>veh "], ["iconHelicopter_ca.paa'/>", "iconHelicopter_ca.paa'/>air "]];
    private _out = ""; private _in = false;
    { if (_x == "<") then { _in = true }; if (!_in) then { _out = _out + _x }; if (_x == ">") then { _in = false } } forEach (_plain splitString "");
    _plain = _out;
};

playSound "CQ_radioIn";
switch (_who) do {
    case "CROSSROAD": {
        ["CROSSROAD", _txt] call CQ_fnc_storyUi;
        [west, "HQ"] sideChat _txt;
        if ((toUpper _txt) find "FLASH" == 0) then { playSound "CQ_alarm" };
    };
    case "MAGPIE": {
        ["MAGPIE", [_txt, "<rich>" + _txt] select _rich, _photos] call CQ_fnc_storyUi;
        if (_photos isNotEqualTo []) then {
            _plain = _plain + " | Photos: " + ((_photos apply { getText (configFile >> "CfgVehicles" >> (_x select 1) >> "displayName") }) joinString ", ");
        };
        systemChat format ["MAGPIE: %1", _plain];
    };
    default {
        ["COMHAT", _txt] call CQ_fnc_storyUi;
        systemChat format ["[COMHAT] %1", _txt];
    };
};

if (isNil "CQ_radioLogMade") then {
    CQ_radioLogMade = true;
    player createDiarySubject ["CQ_radio", "Radio log"];
};
private _t = daytime;
private _m = floor ((_t % 1) * 60);
player createDiaryRecord ["CQ_radio", [format ["%1:%2%3  %4", floor _t, ["", "0"] select (_m < 10), _m, _who], _plain]];
