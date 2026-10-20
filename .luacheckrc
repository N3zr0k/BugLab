-- Lint für WoW-Lua 5.1. Fremde Libraries werden nicht geprüft.
std = "lua51"
max_line_length = false
exclude_files = { "BugLab/Libs/" }
-- WoW-Globals sind nicht einzeln aufgelistet: undefinierte/globale Zugriffe (11x) werden nicht gemeldet,
-- geprüft werden Syntax, ungenutzte Variablen und Überdeckungen.
ignore = { "11[123]", "212", "213" }
