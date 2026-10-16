"""Placeholders: the sounds shipped before the pipeline, kept until their family is rebuilt.

Each reads its committed 48 kHz (44.1 kHz for beds) WAV under sources/legacy/<family>/, resamples to the mix
rate and ships it untouched (level=None skips trim and loudness). A family's batch replaces these with
built sounds; delete the legacy files with it.
"""
from functools import partial

from lib import dsp
from lib.master import Sound


def _build(family, name, rng):
    return dsp.legacy(family, name)


def legacy(family, name, ids, loop=False, level=None):
    """A placeholder Sound named `name` (the file's name) that plays `ids` = [(event id, volume_db, pitch)]."""
    return Sound(name, partial(_build, family, name), family, level, tuple(ids), loop)
