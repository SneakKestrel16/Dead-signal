"""Scare events (placeholder, family `scare`) and the stinger (family `stinger`)."""
from sounds._legacy import legacy

SCARES = ["transformation_reveal", "door_burst", "ambush_lunge", "blackout", "slammed_door", "glass_break",
          "alarm_fuse", "alarm_evacuation", "recording_room", "recording_script", "surveillance_image"]

SOUNDS = [legacy("scare", "scare_" + s, [("scare/" + s, 0.0, 1.0)]) for s in SCARES]
# The stinger is levelled (not kept as shipped): the old integrated-loudness number does not carry over to the
# momentary measure, and the stinger must sit at most 6 dB over every bed as played (SE-8 AC-2, unit test).
SOUNDS.append(legacy("stinger", "scare_stinger", [("scare/stinger", 0.0, 1.0)], level=-30.5))
