# Warrior_V3 equipment QA

2026-09-05. **Stage 4: DONE_AND_PRESENT. SOCKET QA = PASS. GODOT EQUIPMENT PREVIEW = PASS. Visual Gate = PASS.**

Stage 3 DONE_AND_PRESENT and STATIC_GODOT_PREVIEW PASS verified from STATUS, RIG_QA and BONE_MAP. Initial rejection: `work/rejected_initial/INITIAL_QA.md`, with original rejected equipment GLBs. Paths below are relative to the equipment directory.

## Production

Both assets: purpose-built Blender 4.5.11 modeling from separate generated concepts. No Tripo calls or credits for Stage 4. Sword: broad diamond-section blade, simple guard, leather grip and pommel. Shield: heater body, reinforced rim, central boss, rear hand bar and two mounting blocks. Sources: `work/WarriorSword_finished.blend`, `work/WarriorShield_finished.blend`.

| Asset | Triangles | Materials | Runtime textures | Skin |
|---|---:|---:|---|---|
| WarriorSword.glb | 994 | 2 | None | None |
| WarriorShield.glb | 1336 | 2 | One 1024×1024 wood base color | None |

Restrained matte metal and dark wood, no glow. Sword local +Y is blade direction and +Z broad face; origin at grip center. Shield local +Y is top and +Z outward; origin at rear hand attachment.

## Separate finger rig

Approved RAW and 23-bone rig remain byte-for-byte intact. Finger articulation exists only in `../rigged/Warrior_V3_RIGGED_EQUIPPABLE.glb` and its Blender source. Thirty finger bones added (three per digit), giving 53 bones. Existing names and parents unchanged. Mapping: `../rigged/BONE_MAP_EQUIPPABLE.json`.

Local weights changed for 2,725 hand vertices; no body remodeling. Thumb pivots and weights fit the existing anatomy; finger curl is distributed across joints. A glove crease remains at the thumb base in magnified views, without visible tearing or detached fingers. Approval covers these static grips, not future animation clips.

Serialized comparison: 23,979 exported vertices before/after, 21,501 body triangles, maximum rest-position deviation 9.20e-7 units. Original bone matrices differ by at most 9.87e-6 through GLB round-trip, with identical parents. Exact floating-point equality is false; tolerance comparison is recorded separately. `work/SERIALIZED_AUDIT.json` contains hashes and measurements. Position-welded equipment objects each have zero boundary edges, multi-face edges and degenerate faces.

## Sockets

WeaponSocket_R: Node3D under BoneAttachment3D on `mixamorig_RightHand` (index 29). OffhandSocket_L: equivalent on `mixamorig_LeftHand` (index 10). Independent unskinned props. Exact fixed local transforms: `work/SOCKET_CONFIG.json`.

| Socket | Desired rest origin, Godot model space | Basis columns X; Y; Z |
|---|---|---|
| WeaponSocket_R | (0.034, 0.699, 0.409) | (0,0,1); (1,0,0); (0,1,0) |
| OffhandSocket_L | (0, 0.699, -0.409) | (1,0,0); (0,0,1); (0,-1,0) |

Local offset = inverse(global skeleton × bone rest) × VisualRoot global × desired transform. Calculated once; poses never change socket offsets. Cardinal facing rotates only VisualRoot.

Grip pose: `../rigged/work/GRIP_POSE.json`. Equipped poses add left-hand pronation -60° about model Blender Y. Equipped COMBAT_STANCE uses left forearm X +95° for shield guard. These are skeletal pose adjustments; the original Stage 3 pose file and production camera remain unchanged. Shield clearance increased by 0.020 units with fitted mounts; unnecessary rear strap removed. Sword grip radius reduced to fit the grasp.

## Gates

| Gate | Result | Evidence |
|---|---|---|
| SWORD_GRIP | PASS | Fingers wrap grip; thumb closes across it; palm/top close-ups |
| SWORD_ROTATION | PASS | Fixed right-hand transform |
| SWORD_SCALE | PASS | Restrained one-handed blade |
| SWORD_WRIST_ALIGNMENT | PASS | Handle in palm, clear of forearm |
| SHIELD_GRIP | PASS | Fingers wrap rear hand bar |
| SHIELD_ROTATION | PASS | Follows left hand; guard faces forward/outward |
| SHIELD_SCALE | PASS | Head, scarf and legs remain readable |
| SHIELD_ARM_ALIGNMENT | PASS | Rear grip and clearance fit hand |
| BODY_INTERSECTION | PASS | No visible torso penetration or weapon through head in tested poses |

| Pose | Result | Observation |
|---|---|---|
| REST_TPOSE | PASS | Closed grips; four cardinal captures |
| COMBAT_STANCE | PASS | Readable guard, sword clear, hair/scarf retained |
| RIGHT_ARM_FORWARD | PASS | Sword follows arm without loss of grip |
| LEFT_ARM_FORWARD | PASS | Shield follows arm; rear face naturally visible |
| BOTH_ARMS_DOWN | PASS | Props clear of legs and floor |
| TORSO_TWIST_LEFT | PASS | Stable attachments |
| TORSO_TWIST_RIGHT | PASS | Stable attachments |

All eleven Godot captures inspected in `../previews/godot_equipment/`; eight magnified renders in `../previews/equipment_grip/`. Identity, hair, scarf, equipment scale and tactical silhouette PASS. Compared with the legacy reference, anatomy, clothing and equipment have clearer forms. Side views naturally foreshorten blade/shield; no direction-specific weapon rotation.

Preview: `tools/warrior_v3/WarriorV3Preview.tscn`, production character camera and lights. Keys 1–4 cardinal, 5 rest, 6 guard, 7 equipment. `--capture-equipment` generates screenshots from real GLBs. No UI, effects, final clips, legacy replacement or battle integration.
