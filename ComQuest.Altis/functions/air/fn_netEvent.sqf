/*
    CQ_fnc_netEvent  (server)
    [_cat, _text, _n] call CQ_fnc_netEvent;
    One message passing through MAGPIE's network, for the tablet's NETWORK tab (CQ_fnc_magReportUi):
      cat  "report" | "contact" | "memory" | "link" | "loss"      n  how many (contacts of one pass)
    Kept CQ_netSpan s (CQ_netEvents: [serverTime, cat, text, n]), counted in CQ_netStats, and
    published with the network health by CQ_fnc_netPub (CQ_fnc_magTick, every pass).
*/
params ["_cat", ["_text", ""], ["_n", 1]];
if (!isServer) exitWith {};
if (isNil "CQ_netEvents") then { CQ_netEvents = [] };
if (isNil "CQ_netStats") then { CQ_netStats = createHashMapFromArray [["contact", 0], ["report", 0], ["loss", 0], ["linkT", 0], ["upT", 0]] };
CQ_netEvents pushBack [serverTime, _cat, _text, _n];
CQ_netEvents = CQ_netEvents select { serverTime - (_x select 0) < CQ_netSpan };
if (_cat in ["contact", "report", "loss"]) then { CQ_netStats set [_cat, (CQ_netStats getOrDefault [_cat, 0]) + _n] };
CQ_netDirty = true;
