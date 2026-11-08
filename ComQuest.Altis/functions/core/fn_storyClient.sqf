/*
    CQ_fnc_storyClient  (client, from CQ_fnc_say through remoteExec)
    [_speaker, _text] call CQ_fnc_storyClient;
      CROSSROAD  wide panel top right (CQ_fnc_storyUi) + Side chat from the BLUFOR HQ
      MAGPIE     typewriter panel bottom centre (CQ_fnc_storyUi) + chat line
      INTERCEPT  red text in the middle of the screen + chat line
    Every line also goes to the "Radio log" page of the map so it can be read again.
*/
params ["_who", "_txt"];
if (!hasInterface) exitWith {};

playSound "CQ_radioIn";
switch (_who) do {
    case "CROSSROAD": {
        ["CROSSROAD", _txt] call CQ_fnc_storyUi;
        [west, "HQ"] sideChat _txt;
        if ((toUpper _txt) find "FLASH" == 0) then { playSound "CQ_alarm" };
    };
    case "MAGPIE": {
        ["MAGPIE", _txt] call CQ_fnc_storyUi;
        systemChat format ["MAGPIE: %1", _txt];
    };
    default {
        [parseText format ["<t color='#d9452b' size='0.75' font='EtelkaMonospacePro'>[INTERCEPT] %1</t>", _txt],
            -1, 0.72, 7, 0.6, 0, 791] spawn BIS_fnc_dynamicText;
        systemChat format ["[INTERCEPT] %1", _txt];
    };
};

if (isNil "CQ_radioLogMade") then {
    CQ_radioLogMade = true;
    player createDiarySubject ["CQ_radio", "Radio log"];
};
private _t = daytime;
private _m = floor ((_t % 1) * 60);
player createDiaryRecord ["CQ_radio", [format ["%1:%2%3  %4", floor _t, ["", "0"] select (_m < 10), _m, _who], _txt]];
