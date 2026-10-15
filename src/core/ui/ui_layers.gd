class_name UiLayers extends RefCounted
## Fixed CanvasLayer numbers for every client UI layer (ADR-0014 §4), like PhysicsLayers. Captions sit above
## scare flashes so they stay readable (ADR-0015, AD-49). Layer numbers must come from here.

const WORLD_MARKERS := 1
const HUD := 2
const SCARE_FX := 3
const CAPTIONS := 4
const OVERLAY := 10
const MODAL := 20
