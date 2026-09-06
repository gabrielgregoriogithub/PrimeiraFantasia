# Warrior_V3 — equipment QA

2026-09-05. **Stage 4: PARTIAL. SOCKET QA = FAIL. GODOT EQUIPMENT PREVIEW = FAIL.**

Preconditions satisfied: Stage 3 DONE_AND_PRESENT, STATIC_GODOT_PREVIEW PASS, commit `378779c`. STATUS, RIG_QA and bone contract consulted. Approved rig/body GLB untouched. Results here are reviewable equipment candidates, not approved final equipment.

## Production

Concepts: built-in image generation, two separate images persisted in `concept/warrior_sword_concept.png` and `concept/warrior_shield_concept.png`. References specify restrained silver/brown fantasy adventurer equipment, no glow or holy ornaments. Modeling: purpose-built Blender 4.5.11 meshes, exported real GLBs; source files in `work/`. No Tripo credits consumed for equipment.

| Asset | Triangles | Materials | Textures | Forms |
|---|---:|---:|---|---|
| WarriorSword.glb | 998 | 2 | None; constant material colors | Diamond-section blade, beveled guard, leather grip/wraps, faceted pommel |
| WarriorShield.glb | 1340 | 2 | None; constant material colors | Heater body, beveled rim, central boss, rivets, rear hand grip/forearm strap |

Counts and logical parts: `work/equipment_stats.json`. Sword local +Y follows blade, +Z broad face; origin at grip center. Shield +Y up, +Z outward; origin at rear hand grip. Objects are separate from the body and have no skin.

## Attachments

Godot BoneAttachment3D per hand, with a child Node3D socket. `WeaponSocket_R` follows `mixamorig:RightHand`; `OffhandSocket_L` follows `mixamorig:LeftHand`. Import may sanitize colon in bone names; code resolves either spelling. Exact resolved bone names and local transforms in `work/SOCKET_CONFIG.json`.

Sword desired rest placement in model coordinates: origin (0.040,0.704,0.385), basis columns (0,0,1), (1,0,0), (0,1,0). Shield: origin (0.009,0.699,-0.405), basis columns (0,0,-1), (0,1,0), (1,0,0). Local socket = inverse(skeleton global × global bone rest) × VisualRoot global × desired model placement. This offset remains fixed across poses/directions. Only VisualRoot turns cardinally; no independent weapon facing logic.

Preview only: `tools/warrior_v3/WarriorV3Preview.tscn`. Key 7 attaches/toggles equipment; keys 1–6 retain Stage 3 controls. Default remains unequipped. Run with `-- --capture-equipment` for capture sequence. No approved rig overwrite, body mesh modification or production gameplay change.

## Hard failure

The 23-bone rig has whole-hand bones, no finger articulation. The approved rest hands are open. Attaching a handle near a palm does not create a grasp: fingers remain extended, and the weapon reads as supported by/overlapping an open hand instead of firmly held. The shield grip similarly fails convincing hand attachment. This is visible in T-pose, combat stance and left-arm-forward captures. Bone attachment itself follows the hand, but that is insufficient for the requested grip gate.

The shield's flat untextured body/rim also falls short of the concept's wood/leather finish; its bright rim/boss competes with the character under unchanged production lighting. No camera adjustment, glow, effects or animation was used to hide these issues.

| Socket gate | Result | Evidence |
|---|---|---|
| SWORD_GRIP | FAIL | Open fingers do not wrap handle |
| SWORD_ROTATION | PASS | Fixed hand-relative offset follows tested poses |
| SWORD_SCALE | PASS | Restrained one-handed blade length |
| SWORD_WRIST_ALIGNMENT | FAIL | Palm proximity is not a correct grasp |
| SHIELD_GRIP | FAIL | Hand remains open at attachment |
| SHIELD_ROTATION | PASS | Fixed relative offset follows hand |
| SHIELD_SCALE | PASS | Medium shield envelope |
| SHIELD_ARM_ALIGNMENT | FAIL | Grip/forearm fit not accepted |
| BODY_INTERSECTION | FAIL | Hand/handle fit not cleared; must resolve before acceptance |

## Pose QA

| Pose | Result | Reason |
|---|---|---|
| REST_TPOSE | FAIL | Open-hand grips |
| COMBAT_STANCE | FAIL | Sword grip unconvincing; shield finish too plain/bright |
| RIGHT_ARM_FORWARD | FAIL | No grasp despite attachment following bone |
| LEFT_ARM_FORWARD | FAIL | Open hand visible against shield attachment |
| BOTH_ARMS_DOWN | FAIL | Hand-grip issue remains |
| TORSO_TWIST_LEFT | FAIL | Hand-grip issue remains |
| TORSO_TWIST_RIGHT | FAIL | Hand-grip issue remains |

Captures from the real Godot-rendered GLBs in `../previews/godot_equipment/`: north_equipped, east_equipped, south_equipped, west_equipped, combat_stance_equipped, right_arm_forward, left_arm_forward, isometric_equipped, both_arms_down, torso_twist_left, torso_twist_right PNGs. All seven required poses and all four directions captured.

**Visual Gate: FAIL.** Hair/scarf remain visible and sockets do not detach, but grip and equipment finish do not meet the acceptance criteria. Do not promote merely because GLBs exist.

## Stop and required next work

No Stage 4 completion commit. Stage 5 cannot start while this equipment gate fails. A future recovery needs a separately versioned equippable rig with proper hand/finger grip posing (preserving approved body shape at rest), then fitted socket offsets and improved wood/metal finish. It must retain the approved Stage 3 file and repeat equipped pose QA. No final animations, combat integration or legacy replacement performed.
