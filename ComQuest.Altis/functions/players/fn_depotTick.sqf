/*
    CQ_fnc_depotTick  (server, director task, every 5 s)
    Keeps the depot stock (CQ_depotVehs) honest:
      - destroyed: out of the list at once, so its slot is back in stock immediately
      - never boarded CQ_depotUnused s after the request: deleted, back in stock
      - abandoned: boarded once, now empty and still for CQ_vehAbandonDelay s with no player
        within 200 m: deleted, back in stock
    Polling on purpose: a vehicle driven by a player is local to him, where a Killed event
    handler added by the server would not fire.
*/
if (isNil "CQ_depotVehs") exitWith {};
private _n = count CQ_depotVehs;
private _keep = [];
{
    private _v = _x;
    if (isNull _v) then { continue };
    private _name = getText (configOf _v >> "displayName");
    if (!alive _v) then {
        ["Depot: %1 destroyed, slot back in stock", [typeOf _v]] call CQ_fnc_log;
        if (time - (missionNamespace getVariable ["CQ_baseVehLostT", -1e6]) > 300) then {
            CQ_baseVehLostT = time;
            ["baseVehLost", [_name]] call CQ_fnc_say;
        };
        continue;
    };
    private _empty = ({ alive _x } count crew _v) == 0;
    if (!_empty) then { _v setVariable ["CQ_depotUsed", true] };
    if (!(_v getVariable ["CQ_depotUsed", false])) then {
        if (_empty && { serverTime - (_v getVariable ["CQ_depotT", serverTime]) > CQ_depotUnused }) then {
            ["Depot: %1 never boarded, back in stock", [typeOf _v]] call CQ_fnc_log;
            deleteVehicle _v;
        } else { _keep pushBack _v };
        continue;
    };
    if (_empty && { speed _v < 1 }) then {
        private _t = _v getVariable ["CQ_abandonT", -1];
        if (_t < 0) then { _v setVariable ["CQ_abandonT", serverTime]; _t = serverTime };
        if (serverTime - _t >= CQ_vehAbandonDelay && { (allPlayers findIf { alive _x && { _x distance _v < 200 } }) == -1 }) then {
            ["Depot: %1 abandoned at %2, back in stock", [typeOf _v, mapGridPosition _v]] call CQ_fnc_log;
            deleteVehicle _v;
            continue;
        };
    } else { _v setVariable ["CQ_abandonT", -1] };
    _keep pushBack _v;
} forEach CQ_depotVehs;
CQ_depotVehs = _keep;
if (count _keep != _n) then { publicVariable "CQ_depotVehs" };
