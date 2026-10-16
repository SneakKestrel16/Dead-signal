"""Doors, barricades, objective alarm and dock (placeholder, family `world`)."""
from sounds._legacy import legacy

SOUNDS = [legacy("world", n, [(n, 0.0, 1.0)]) for n in
          ["door_open", "door_close", "barricade_build", "barricade_break", "objective_dock", "objective_alarm"]]
