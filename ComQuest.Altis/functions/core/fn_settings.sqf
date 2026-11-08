/*
    CQ_fnc_settings  (preInit, every machine)
    Loads cfg\settings.sqf so server and clients share the same values.
*/
call compile preprocessFileLineNumbers "cfg\settings.sqf";
diag_log text "[CQ] Settings loaded";
