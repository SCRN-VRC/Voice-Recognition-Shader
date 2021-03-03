This is a world fixed object, held in place by a limb ik script connected to nothing. This requires Final IK versions 1.6.1 to 1.7.1

This is more stable than a world fixed joint. If you are not using fullbody tracking, it will sway slightly with IK movements, such as the resting IK step when you first stop moving. If you have fullbody tracking, it will not move at all.

The child objects will reset their position every time world_fixed_object is enabled.

# install
1. Place the world_fixed_ik.prefab at the base of your avatar. It must be at the base of your avatar for best performance.
2. Put world_fixed_object.prefab anywhere in your scene.
3. Assign world_root, world_offset, world_end as bone 1, 2, 3 in the world_fixed_ik script settings.
4. Animate world_fixed_object on however you would like.

Guide video: https://youtu.be/1oL1ZNoKBxo
