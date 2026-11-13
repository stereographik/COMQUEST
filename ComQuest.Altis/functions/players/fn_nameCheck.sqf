/*
    CQ_fnc_nameCheck  (any machine)
    [_name] call CQ_fnc_nameCheck  ->  "" if the name is fine, else the reason (shown to the player)
    Very strict (cfg\rules.sqf): length, allowed characters, letters, repeats, spaces, reserved and
    default names, forbidden words (normalised: case, look-alike digits/symbols, separators,
    repeated letters). Duplicates are checked by CQ_fnc_conduct (needs the other players).
*/
params [["_name", ""]];
private _n = count _name;
if (_n < CQ_nameMin) exitWith { format ["Your name is too short (%1 characters, %2 minimum).", _n, CQ_nameMin] };
if (_n > CQ_nameMax) exitWith { format ["Your name is too long (%1 characters, %2 maximum).", _n, CQ_nameMax] };
private _codes = toArray _name;
private _allowed = { (_this >= 48 && _this <= 57) || { _this >= 65 && _this <= 90 } || { _this >= 97 && _this <= 122 } || { _this in [32, 45, 95, 46] } };
private _bad = _codes select { !(_x call _allowed) };
if (_bad isNotEqualTo []) exitWith { format ["Your name contains characters that are not allowed (%1). Use only letters A-Z, digits, spaces, - _ or .", toString (_bad arrayIntersect _bad)] };
if ((_codes select 0) == 32 || { (_codes select (_n - 1)) == 32 } || { _name find "  " > -1 }) exitWith { "Your name starts or ends with a space, or has double spaces." };
private _letters = { (_x >= 65 && _x <= 90) || { _x >= 97 && _x <= 122 } } count _codes;
if (_letters < CQ_nameMinLetters) exitWith { format ["Your name needs at least %1 letters.", CQ_nameMinLetters] };
private _run = 1; private _maxRun = 1;
for "_i" from 1 to _n - 1 do {
    if ((_codes select _i) == (_codes select (_i - 1))) then { _run = _run + 1; _maxRun = _maxRun max _run } else { _run = 1 };
};
if (_maxRun > CQ_nameMaxRepeat) exitWith { format ["Your name repeats the same character more than %1 times in a row.", CQ_nameMaxRepeat] };

// normalised forms: lower case, look-alike digits read as letters; separators kept (whole words)
// or removed (flat); plain words: the letters only, digits dropped ("Player1" -> "player")
private _low = toLower _name;
private _isL = { private _c = (toArray _this) select 0; _c >= 97 && _c <= 122 };
private _plain = (((_low splitString "") apply { [" ", _x] select (_x call _isL) }) joinString "") splitString " ";
private _map = createHashMapFromArray [["0", "o"], ["1", "i"], ["3", "e"], ["4", "a"], ["5", "s"], ["7", "t"], ["8", "b"]];
private _chars = (_low splitString "") apply { _map getOrDefault [_x, _x] };
private _collapse = {
    private _out = []; private _prev = "";
    { if (_x != _prev) then { _out pushBack _x }; _prev = _x } forEach _this;
    _out joinString ""
};
private _isLetter = { private _c = toArray _this select 0; _c >= 97 && _c <= 122 };
private _flat = (_chars select { _x call _isLetter }) call _collapse;                       // "f.u_c k" -> "fuck"
private _words = ((_chars apply { [" ", _x] select (_x call _isLetter) }) joinString "") splitString " ";
_words = _words apply { (_x splitString "") call _collapse };

private _res = CQ_nameReserved findIf { private _r = _x; (_flat find _r) == 0 || { (_words + _plain) findIf { _x == _r } > -1 } };
if (_res > -1) exitWith { format ["Names may not use ""%1"" (reserved).", CQ_nameReserved select _res] };
private _def = CQ_nameDefaults findIf { private _d = _x; (_plain findIf { _x == _d }) > -1 };
if (_def > -1) exitWith { "That is a default profile name. Pick your own name." };
private _hit = CQ_nameBadWords findIf { _flat find ((_x splitString "") call _collapse) > -1 };
if (_hit < 0) then {
    // whole words: as written, or with repeated letters collapsed (never down to a single letter: "Agent K" is fine)
    _hit = CQ_nameBadWholeWords findIf {
        private _e = _x; private _w = (_x splitString "") call _collapse;
        (_plain findIf { _x == _e }) > -1 || { count _w >= 2 && { (_words findIf { _x == _w }) > -1 } }
    };
};
if (_hit > -1) exitWith { "Your name contains a forbidden word." };
""
