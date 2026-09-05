# Warrior_V3 — Stage 3 rig QA

Date: 2026-09-05. **Rig QA: PASS. STATIC_GODOT_PREVIEW = PASS.**

## Source and audit

Official input: `../raw/Warrior_V3_RAW.glb`, unchanged SHA-256 `dd199f76f39c5b1de37ad7f00ba2d338620edff4fb3dee44d5469bb6befe28b0`. Stage 2 reports and Design Lock read before rigging. Blender input: +X forward, +Z up, center (0,0,0), bounds Z ±0.499755859375, height 0.99951171875. T-pose, bilateral limb separation, distinct hands/feet, head/hair/scarf preserved. Small original asymmetries retained.

The remaining four multi-face contacts at lips and one at boot hardware were not remeshed or automatically repaired. Head rotation and knee tests did not show them causing tearing or detached pieces. They remain limitations of the original mesh; no facial rig is provided.

## Method and provenance

Tripo v3 humanoid auto-rig, followed by Blender 4.5.11 inspection/serialization. Documentation: [auto-rig](https://developers.tripo3d.ai/en/docs/animations-rig), [rig-check](https://developers.tripo3d.ai/en/docs/animations-rig-check).

- POST `/v3/animations/rig-check`: task `a54500fe-5d15-4679-9680-ccfbeeb7e242`, riggable=true, biped, **0 credits**.
- POST `/v3/animations/rig`: task `2dcc9eeb-9e93-4277-b0d8-8f732a07c6f9`, **25 credits**.
- Parameters: `model=v1.0-20240301`, `rig_type=biped`, `spec=mixamo`, `out_format=glb`; input is uploaded official RAW file_token, not the original uncleaned generation task.
- Exact requests, responses, task timestamps, balances and output URLs: `work/tripo/check.json`, `work/tripo/rig.json`, `work/tripo/upload.json`.
- Original service GLB preserved in `work/tripo/Warrior_V3_Tripo_Rig.glb`.

23 bones, 23 named vertex groups, no unweighted body vertices. Full names and contract mapping in [BONE_MAP.json](BONE_MAP.json). Root and Hips are distinct. Three spine sections, clavicles, neck/head, paired arms/hands and legs/feet/toes. No facial bones/blendshapes or final animations added.

The service included an auxiliary Icosphere; removed from the deliverable, leaving only the skinned approved character. Service normalization translates the soles to zero and uniformly rescales the original height to ~1. Root/Hips were not used to disguise scale/orientation. A whole-asset parent preserves global transformation; a residual ~0.0000002 ground offset is corrected there.

Geometry: 21,501 triangles maintained. Nearest-position comparison against uniformly normalized RAW: max delta 0.000001669, mean 0.000000683. Details in `work/geometry_weight_audit.json`. One material, 2048×2048 color texture, no material restyling in Blender.

## Skinning and local corrections

Automatic weights are from Tripo. **No manual weight corrections applied**: observed tests did not justify changing accepted regions. An initial broad coordinate probe around scarf height included upper-arm surfaces and therefore was not treated as proof of wrong scarf weights. Actual scarf motion was reviewed in arm, head and torso tests. Hair follows head; face remains coherent without a facial rig. Boot hardware stays attached in the knee test.

## Pose QA

All ten poses have front/back/left/right/3q renders under `../previews/rig/`. They were rendered after reimporting the serialized rig candidate, with Cycles 24 samples, neutral world and simple three-light setup. These are static diagnostic poses, not final animation clips. Definitions: `work/TEST_POSES.json`; bounds and finite-coordinate checks: `work/pose_stats.json`.

| Pose | Result | Observation |
|---|---|---|
| REST_TPOSE | PASS | Original limb clearance and identity retained |
| COMBAT_STANCE | PASS | Partial arm lowering and mild knee bend remain coherent |
| RIGHT_ARM_FORWARD | PASS | Shoulder/forearm/hand stay attached |
| LEFT_ARM_FORWARD | PASS | Arm and scarf stay coherent |
| BOTH_ARMS_DOWN | PASS | No strong shoulder collapse; cuff compression remains modest |
| KNEE_BEND | PASS | Knee bends forward; boot follows leg/foot chain |
| TORSO_TWIST_LEFT | PASS | Torso, jerkin and scarf follow twist without tearing |
| TORSO_TWIST_RIGHT | PASS | Reverse twist remains coherent |
| HEAD_LEFT | PASS | Hair follows head, face retained, no neck/scarf tearing |
| HEAD_RIGHT | PASS | Reverse head turn remains coherent |

| Gate | Result |
|---|---|
| SKELETON | PASS |
| ROOT | PASS |
| HIPS | PASS |
| SPINE | PASS |
| HEAD | PASS |
| SHOULDERS | PASS |
| ELBOWS | PASS |
| WRISTS | PASS |
| HANDS | PASS |
| HIPS_DEFORMATION | PASS |
| KNEES | PASS |
| FEET | PASS |
| HAIR | PASS |
| SCARF | PASS |
| CLOTHING | PASS |
| GROUND | PASS |
| OVERALL_RIGGABILITY | PASS |

PASS is scoped to the tested static ranges. Extreme athletic motion, finger articulation and future equipped animation clips require their own QA. Hands currently move as whole hands; there are no finger bones.

## Stage 3A: Godot preview

Scene: `res://tools/warrior_v3/WarriorV3Preview.tscn`. Godot 4.7.2, GL Compatibility, actual GPU capture. Uses GLTFDocument to load the serialized approved GLB directly. Controls: 1 NORTH, 2 EAST, 3 SOUTH, 4 WEST, 5 REST_TPOSE, 6 COMBAT_STANCE. One rig; only VisualRoot rotates. Imported forward +X; cardinal Y angles +90, 0, -90, 180 degrees respectively.

Production `CharacterVisual3D.tscn` camera transform, orthographic size 2.65, near/far and KeyLight/FillLight/environment are copied without the production gameplay node. Ground is a simple matte green plane and engine shadow; no UI/VFX/particles. Asset display scale 1.0, grounded locally. This is an isolated model preview, not a battle integration or complete tactical map recreation.

Initial capture issues were corrected: an oversized display scale was reset to 1.0; test rotations now multiply the bone rest rotation instead of replacing it. Camera was not changed. Five final screenshots: `../previews/godot_static/north.png`, `east.png`, `south.png`, `west.png`, `isometric.png` (combat stance). Comparison reference: existing `artifacts/warrior_polish/idle_model.png` from legacy gameplay capture. V3 shows coherent anatomical/clothing forms and recognisable blue hair/red scarf where legacy preview has block-like forms.

| Static gate | Result |
|---|---|
| IDENTITY | PASS |
| SILHOUETTE | PASS |
| SCALE | PASS |
| GROUNDING | PASS |
| MATERIAL | PASS |
| HAIR READABILITY | PASS |
| SCARF READABILITY | PASS |
| TACTICAL CAMERA READABILITY | PASS |

**STATIC_GODOT_PREVIEW = PASS.** No camera change to hide defects. Final `Warrior_V3_RIGGED.glb` present; source `work/Warrior_V3_RIGGED.blend` preserved. No legacy replacement, gameplay change or final animation in Stage 3.
