/*
    ComQuest SHOWCASE  (branch "showcase" only, never merged into main)
    Compositions from https://github.com/CntoDev/compositions (CC-BY-SA-4.0, authors in
    cfg\comps.sqf and CREDITS.md), converted by tools/convert_compositions.py, laid out on plots
    around the main airport; the menu teleports, places your own copies and exports a layout.
*/
SC_origin = [14267, 16099];        // ComQuest's base spot at the main airport
SC_firstRing = 180;                // m: the nearest plots
call compile preprocessFileLineNumbers "cfg\comps.sqf";
if (isServer) then {
    call SC_fnc_validate;
    call SC_fnc_layout;
    SC_ready = true; publicVariable "SC_ready";
};
if (hasInterface) then {
    [] spawn {
        waitUntil { !isNull player && { !isNil "SC_ready" } };
        private _p = SC_origin getPos [20, 0];
        player setPosATL [_p select 0, _p select 1, 0];
        player addAction ["<t color='#918C3B'>Showcase menu</t>", { [] spawn SC_fnc_menu }, nil, 1.5, false, true];
        player addEventHandler ["Respawn", { params ["_u"]; _u addAction ["<t color='#918C3B'>Showcase menu</t>", { [] spawn SC_fnc_menu }, nil, 1.5, false, true] }];
        hint "Showcase ready: open the scroll menu > Showcase menu.";
    };
};
