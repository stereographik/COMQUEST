/*
    CQ_fnc_settings  (preInit, every machine)
    Loads cfg\settings.sqf so server and clients share the same values.
*/
call compile preprocessFileLineNumbers "cfg\settings.sqf";
call compile preprocessFileLineNumbers "cfg\story.sqf";
call compile preprocessFileLineNumbers "cfg\version.sqf";
call compile preprocessFileLineNumbers "cfg\guide.sqf";
call compile preprocessFileLineNumbers "cfg\rules.sqf";
diag_log text "[CQ] Settings loaded";
