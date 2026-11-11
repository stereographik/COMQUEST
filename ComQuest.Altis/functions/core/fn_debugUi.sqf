/*
    CQ_fnc_debugUi  (client)  F3, or the scroll action "Debug panel"
    Who: the host or a logged-in admin (#login) only, also in debug missions (voted admins: no).
    Left: enemy HQ list (select one for the HQ buttons) and a status block.
    Right: buttons by category. Server commands go through CQ_fnc_debugCmd; a few are local
    (map overlays, god mode, arsenal). Toggles show their state in their label.
    Refreshes every 3 s while open.
*/
if (!hasInterface) exitWith {};
if !(isServer || { (call BIS_fnc_admin) == 2 }) exitWith { hint "Debug panel: host or logged-in admin only" };
disableSerialization;
if (!isNull (uiNamespace getVariable ["CQ_dbgDisplay", displayNull])) exitWith {};
call CQ_fnc_debugMap;     // makes sure the map overlay exists (toggles below)
if (isNil "CQ_dbgGod") then { CQ_dbgGod = false };

private _d = (findDisplay 46) createDisplay "RscDisplayEmpty";
uiNamespace setVariable ["CQ_dbgDisplay", _d];
_d displayAddEventHandler ["KeyDown", { params ["_d", "_k"]; if (_k == 22) then { _d closeDisplay 1; true } else { false } }];   // U closes it

private _W = safeZoneW * 0.86;
private _H = safeZoneH * 0.86;
private _X = safeZoneX + (safeZoneW - _W) / 2;
private _Y = safeZoneY + (safeZoneH - _H) / 2;
private _L = 0.036;                                     // line height
private _mk = {
    params ["_cls", "_idc", "_pos", ["_txt", ""]];
    private _c = _d ctrlCreate [[_cls, "CQ_Button"] select (_cls == "RscButton"), _idc];
    [_c, _cls] call CQ_fnc_uiStyle;
    _c ctrlSetPosition _pos;
    if (_txt != "") then { _c ctrlSetText _txt };
    _c ctrlCommit 0;
    _c
};
(["RscText", -1, [_X, _Y, _W, _H]] call _mk) ctrlSetBackgroundColor (CQ_ui get "panel");
(["RscText", -1, [_X, _Y, 0.004, _H]] call _mk) ctrlSetBackgroundColor (CQ_ui get "accent");
private _title = ["RscText", -1, [_X + 0.015, _Y + 0.004, _W * 0.5, _L * 1.1], "COMQUEST DEBUG"] call _mk;
_title ctrlSetFont "PuristaMedium";
_title ctrlSetTextColor (CQ_ui get "accent");
private _close = ["RscButton", -1, [_X + _W - 0.05, _Y + 0.004, 0.04, _L], "X"] call _mk;
_close ctrlAddEventHandler ["ButtonClick", { (uiNamespace getVariable ["CQ_dbgDisplay", displayNull]) closeDisplay 1 }];

// ---- left: status + HQ list
private _lw = _W * 0.38;
private _status = ["RscStructuredText", 9001, [_X + 0.015, _Y + _L * 1.3, _lw, _L * 5.2]] call _mk;
_status ctrlSetBackgroundColor (CQ_ui get "inset");
(["RscText", -1, [_X + 0.015, _Y + _L * 6.7, _lw, _L * 0.8], "ENEMY HQs  (select one for the HQ buttons)"] call _mk) ctrlSetTextColor (CQ_ui get "muted");
private _list = ["RscListBox", 9000, [_X + 0.015, _Y + _L * 7.6, _lw, _H - _L * 8.2]] call _mk;

uiNamespace setVariable ["CQ_dbgSel", {
    private _lb = (uiNamespace getVariable ["CQ_dbgDisplay", displayNull]) displayCtrl 9000;
    private _i = lbCurSel _lb;
    if (_i < 0) then { -1 } else { parseNumber (_lb lbData _i) }
}];

// ---- right: categories of buttons
// [label, command]; command "!x" = local action, else sent to the server
private _cats = [
    ["ENEMY HQ (selected)", [
        ["Next phase", "next"], ["+200 ammo", "ammo"], ["+200 fuel", "fuel"],
        ["Kill commander", "killCmd"], ["Capture commander", "capture"], ["Destroy radio tower", "tower"],
        ["Destroy depot", "depot"], ["Destroy fuel tanker", "tanker"], ["Destroy whole HQ", "destroy"], ["Reinforcement wave now", "wave"]
    ]],
    ["CARRIER & ENEMY FORCES", [
        ["Landing now", "root"], ["Supply flight now", "flight"], ["Carrier -1 HQ", "carrierMinus"],
        ["Carrier full", "carrierFull"], ["Kill all enemies", "killAll"], ["Full power (4 full squads)", "!fullPower"]
    ]],
    ["STORY & RADIO", [
        ["Next act", "actNext"], ["SITREP now", "sitrep"], ["Reset speech budget", "storyReset"]
    ]],
    ["EVENTS", [
        ["Trigger crash", "crash"], ["Teleport to crash", "tpCrash"], ["Decrypt now", "decrypt"], ["Retrieve (timer out)", "crashOut"],
        ["Outpost: build", "opBuild"], ["Outpost: destroy", "opKill"], ["Teleport to outpost", "tpOp"], ["Outpost: jammer off", "opJam"]
    ]],
    ["MAGPIE (UAV)", [
        ["Report now", "magReport"], ["Launch missing drones", "magLaunch"], ["Shoot down drones", "magKill"]
    ]],
    ["PLAYER", [
        ["Heal me", "heal"], ["Teleport to base", "tpBase"], ["Teleport to selected HQ", "tpHq"],
        ["God mode", "!god"], ["Arsenal here", "!arsenal"], ["+500 squad points", "points"],
        ["Repair / refuel my vehicle", "vehFix"]
    ]],
    ["BASE & WORLD", [
        ["Depot: stock + cooldowns reset", "vehReset"], ["Rebuild base defences", "defRebuild"], ["+1 hour", "time1"],
        ["Noon", "noon"], ["Night", "night"], ["Clear weather", "clearWx"]
    ]],
    ["MAP OVERLAY, LOGS & VIEW", [
        ["Enemies on map", "!mapEnemy"], ["Friendlies on map", "!mapFriend"], ["HQ sites on map", "!mapHq"],
        ["Show all enemy logs", "!logEnemy"], ["Show all friendly logs", "!logFriend"], ["FINAL PLAYER VIEW", "!playerView"]
    ]]
];
private _rx = _X + 0.03 + _lw;
private _rw = _W - (_rx - _X) - 0.015;
private _cols = 3;
private _bw = (_rw - (_cols - 1) * 0.008) / _cols;
private _y = _Y + _L * 1.3;
private _toggles = [];
{
    _x params ["_cat", "_btns"];
    private _h = ["RscText", -1, [_rx, _y, _rw, _L * 0.8], _cat] call _mk;
    _h ctrlSetFont "PuristaMedium";
    _h ctrlSetTextColor (CQ_ui get "accent");
    _y = _y + _L * 0.85;
    {
        _x params ["_label", "_cmd"];
        private _c = _forEachIndex mod _cols;
        if (_c == 0 && { _forEachIndex > 0 }) then { _y = _y + _L * 1.05 };
        private _b = ["RscButton", -1, [_rx + _c * (_bw + 0.008), _y, _bw, _L * 0.95], _label] call _mk;
        _b setVariable ["CQ_cmd", _cmd];
        _b setVariable ["CQ_label", _label];
        if ((_cmd select [0, 1]) == "!" && { _cmd != "!arsenal" }) then { _toggles pushBack _b };
        _b ctrlAddEventHandler ["ButtonClick", {
            params ["_ctrl"];
            private _cmd = _ctrl getVariable ["CQ_cmd", ""];
            switch (_cmd) do {
                case "!mapEnemy": { CQ_dbgShowEnemy = !CQ_dbgShowEnemy };
                case "!mapFriend": { CQ_dbgShowFriend = !CQ_dbgShowFriend };
                case "!mapHq": { CQ_dbgShowHq = !CQ_dbgShowHq };
                case "!fullPower": {
                    private _on = !(missionNamespace getVariable ["CQ_testFullPower", false]);
                    CQ_testFullPower = _on;        // label right away; the server applies it
                    ["fullPower", [0, 1] select _on] remoteExec ["CQ_fnc_debugCmd", 2];
                };
                case "!logEnemy";
                case "!logFriend": {
                    private _f = +(missionNamespace getVariable ["CQ_myLogs", [false, false]]);
                    private _i = [0, 1] select (_cmd == "!logFriend");
                    _f set [_i, !(_f select _i)];
                    CQ_myLogs = _f;                // label right away; the server answers with the same value
                    ["logs", ([0, 1] select (_f select 0)) + ([0, 2] select (_f select 1))] remoteExec ["CQ_fnc_debugCmd", 2];
                };
                case "!god": { CQ_dbgGod = !CQ_dbgGod; player allowDamage !CQ_dbgGod; if (vehicle player != player) then { (vehicle player) allowDamage !CQ_dbgGod } };
                case "!playerView": {
                    private _on = !(missionNamespace getVariable ["CQ_playerView", false]);
                    if (_on) then { CQ_dbgShowEnemy = false; CQ_dbgShowFriend = false; CQ_dbgShowHq = false; CQ_dbgGod = false; player allowDamage true };
                    CQ_playerView = _on;       // label right away; the server publishes the same value
                    ["playerView", [0, 1] select _on] remoteExec ["CQ_fnc_debugCmd", 2];
                };
                case "!arsenal": { (uiNamespace getVariable ["CQ_dbgDisplay", displayNull]) closeDisplay 1; ["Open", true] spawn BIS_fnc_arsenal };
                default { [_cmd, call (uiNamespace getVariable "CQ_dbgSel")] remoteExec ["CQ_fnc_debugCmd", 2] };
            };
            call (uiNamespace getVariable ["CQ_dbgToggleLabels", {}]);
        }];
    } forEach _btns;
    _y = _y + _L * 1.25;
} forEach _cats;
uiNamespace setVariable ["CQ_dbgToggles", _toggles];
uiNamespace setVariable ["CQ_dbgToggleLabels", {
    {
        private _cmd = _x getVariable ["CQ_cmd", ""];
        private _on = switch (_cmd) do {
            case "!mapEnemy": { CQ_dbgShowEnemy };
            case "!mapFriend": { CQ_dbgShowFriend };
            case "!mapHq": { CQ_dbgShowHq };
            case "!fullPower": { missionNamespace getVariable ["CQ_testFullPower", false] };
            case "!logEnemy": { (missionNamespace getVariable ["CQ_myLogs", [false, false]]) select 0 };
            case "!logFriend": { (missionNamespace getVariable ["CQ_myLogs", [false, false]]) select 1 };
            case "!god": { CQ_dbgGod };
            case "!playerView": { missionNamespace getVariable ["CQ_playerView", false] };
            default { false };
        };
        _x ctrlSetText format ["%1: %2", _x getVariable ["CQ_label", ""], ["OFF", "ON"] select _on];
        _x ctrlSetTextColor ([(CQ_ui get "muted"), [0.55, 0.95, 0.45, 1]] select _on);
    } forEach (uiNamespace getVariable ["CQ_dbgToggles", []]);
}];
call (uiNamespace getVariable "CQ_dbgToggleLabels");

["list", -1] remoteExec ["CQ_fnc_debugCmd", 2];
[] spawn {
    disableSerialization;
    while { !isNull (uiNamespace getVariable ["CQ_dbgDisplay", displayNull]) } do {
        sleep 3;
        ["list", -1] remoteExec ["CQ_fnc_debugCmd", 2];
    };
};
