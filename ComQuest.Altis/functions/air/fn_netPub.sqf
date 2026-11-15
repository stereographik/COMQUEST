/*
    CQ_fnc_netPub  (server, end of every CQ_fnc_magTick pass)
    The NETWORK tab's data: CQ_mnetPub = [events, health, state, stats] (published every
    CQ_netPubEvery s, or at once after a new message)
      health  [link "OK"|"DEGRADED"|"CUT", nodes linked, nodes, [[drone, "up"|"lost mm:ss"|"pad"]...], relay text]
      state   [phase line, WASP line]
      stats   [contacts, reports, drones lost, link uptime %]
*/
if (!isServer) exitWith {};
if (isNil "CQ_netStats") then { CQ_netStats = createHashMapFromArray [["contact", 0], ["report", 0], ["loss", 0], ["linkT", 0], ["upT", 0]] };
// link uptime: share of passes with WASP (or, without it, the relay vehicle) linked
private _wasp = CQ_mag select { (_x getOrDefault ["role", ""]) == "wasp" };
private _wv = if (_wasp isEqualTo []) then { objNull } else { (_wasp select 0) get "veh" };
private _rv = missionNamespace getVariable ["CQ_linkRelayVeh", objNull];
private _dt = time - (missionNamespace getVariable ["CQ_netLastT", time]);
CQ_netLastT = time;
CQ_netStats set ["linkT", (CQ_netStats get "linkT") + _dt];
private _up = (alive _wv && { _wv getVariable ["CQ_linked", false] }) || { !alive _wv && { alive _rv } && { _rv getVariable ["CQ_linked", true] } };
if (_up) then { CQ_netStats set ["upT", (CQ_netStats get "upT") + _dt] };
if (!(missionNamespace getVariable ["CQ_netDirty", false]) && { time - (missionNamespace getVariable ["CQ_netPubT", -1e6]) < CQ_netPubEvery }) exitWith {};
CQ_netDirty = false;
CQ_netPubT = time;
// health
private _nodes = (missionNamespace getVariable ["CQ_linkPub", []]) param [0, []];
private _nl = { _x select 2 } count _nodes;
private _cut = !isNil "CQ_lr" && { !isNull (CQ_lr getOrDefault ["target", objNull]) };
private _link = switch (true) do { case (_cut): { "CUT" }; case (_nl < count _nodes): { "DEGRADED" }; default { "OK" } };
private _fmt = { params ["_s"]; _s = (round _s) max 0; format ["%1:%2", floor (_s / 60), [str (_s mod 60), "0" + str (_s mod 60)] select ((_s mod 60) < 10)] };
private _drones = [];
{
    private _m = _x;
    private _role = _m getOrDefault ["role", ""];
    if (_role in ["dormant", "chain"]) then { continue };
    private _v = _m get "veh";
    private _nm = (_m get "name") regexReplace ["Sentinel_", ""];
    private _st = switch (true) do {
        case (alive _v && { ((getPosATL _v) select 2) > 20 }): { "up" };
        case (alive _v): { "pad" };
        default { format ["lost %1", [(_m getOrDefault ["due", time]) - time] call _fmt] };
    };
    _drones pushBack [toUpper _nm, _st];
} forEach CQ_mag;
private _wk = { (_x getOrDefault ["role", ""]) == "dormant" && { alive (_x get "veh") } } count CQ_mag;
_drones pushBack ["WATCHERS", str _wk];
private _rvTxt = switch (true) do {
    case (!alive _rv): { "lost" };
    case (speed _rv > 3): { "moving" };
    default { "on station" };
};
// state
private _phase = switch (true) do {
    case (!isNil "CQ_lr" && { !isNull (CQ_lr getOrDefault ["target", objNull]) }): { "Link repair in progress" };
    case ((missionNamespace getVariable ["CQ_tntPub", []]) isNotEqualTo []): {
        CQ_tntPub params ["_ch", "_rg", "_pe"];
        format ["Tentacle to zone %1 · %2 chain · %3 on the ring", mapGridPosition (_pe select 0), (count _ch - 1) max 0, count _rg]
    };
    case (isNil "CQ_magContactMade"): { "Orbiting WASP, waiting for a first contact" };
    default {
        private _f = missionNamespace getVariable ["CQ_magFocus", []];
        if (_f isEqualTo []) then { "Searching for contacts" } else { format ["Focus on the contacts at %1", mapGridPosition _f] }
    };
};
private _waspTxt = switch (true) do {
    case (!alive _wv): { "WASP down" };
    case (missionNamespace getVariable ["CQ_waspBridge", false]): { "WASP bridging toward the Darters' zone" };
    default { "WASP facing the carrier" };
};
private _lt = (CQ_netStats get "linkT") max 1;
CQ_mnetPub = [
    missionNamespace getVariable ["CQ_netEvents", []],
    [_link, _nl, count _nodes, _drones, _rvTxt],
    [_phase, _waspTxt],
    [CQ_netStats get "contact", CQ_netStats get "report", CQ_netStats get "loss", round (100 * (CQ_netStats get "upT") / _lt)]
];
publicVariable "CQ_mnetPub";
