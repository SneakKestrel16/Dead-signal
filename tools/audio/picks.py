"""The designer's picks from the review pages (tools/audio/review/<family>/, picks.json exports of 2026-10-16).

Name -> the option that ships: "A" to "F" (a candidate, kept with the bytes it was heard with), several letters ("CB":
each a take, played at random), or "before" (the take that shipped before the pipeline, sources/legacy/<family>/, as
built). A sound not listed ships A. Round 1 notes and what each round-2 page asks are in docs/audio/picks.md.
"""

SHIP = {
    # ambience
    "amb_a": "B", "amb_b": "A", "amb_c": "B", "amb_link": "B",
    # voices
    "callout_c1": "B", "callout_c2": "A", "callout_c3": "A", "callout_c4": "A", "callout_c5": "A",
    "pain_cry_true_form": "C",
    # scares
    "scare_transformation_reveal": "B", "scare_door_burst": "C", "scare_ambush_lunge": "C", "scare_blackout": "B",
    "scare_slammed_door": "C", "scare_alarm_fuse": "C", "scare_recording_room": "B",
    "scare_recording_script": "C", "scare_surveillance_image": "A", "scare_stinger": "B",
    # ui
    "ui_click": "A", "ping_rejected": "C",
    # steps
    "step_concrete": "B", "step_metal": "C", "step_rubber": "A", "step_true_form": "C",
    # cues
    "lunge_scrape": "A", "taser_crackle": "B", "taser_fizz": "before", "hide_cue": "CB",
    "hide_enter": "B", "hide_exit": "C",
    # world
    "door_open": "before", "door_close": "before", "barricade_break": "B", "objective_dock": "before",
    "objective_alarm": "B",
    # round 2 (picks_<family>_r2.json, 2026-10-16)
    "grunt_c1": "F", "grunt_c2": "E", "grunt_c3": "D", "grunt_c4": "D", "grunt_c5": "F",
    "scare_glass_break": "E", "scare_alarm_evacuation": "F", "step_tile": "D",
    "lunge_cue": "F", "lunge_hit": "E", "distortion": "E", "fuse_install": "F", "barricade_build": "D",
    # states (picks (7).json, 2026-10-17); heartbeat, breath_sprint, flashlight_click, pa_chime, phase_tick,
    # phase_win and phase_loss picked A
    "generator_spinup": "B", "terminal_tone": "B", "phase_investigation": "B",
    # events (picks (8).json, 2026-10-17); drive_clatter, install_alert, rescue_relief, barricade_loop, rescue_loop
    # and face_unlock picked A; body_collapse was added after the page and ships A unpicked
    "drive_eject": "B", "relay_clack": "B", "eliminated_sting": "C", "search_rattle": "B", "takedown_struggle": "B",
    "release_gasp": "C", "interact_loop": "C", "ping_tick": "C", "ping_warning": "B",
}
