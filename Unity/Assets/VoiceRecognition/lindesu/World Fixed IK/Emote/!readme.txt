This is a world fixed object managed by an emote. This uses a pre-configured ik script.

The enable_world_object_animator.controller plays enable_world_object.anim, which animates world_fixed_object ON.

The disable_world_object_animator.controller plays disable_world_object.anim, which animates world_fixed_object OFF.

# install
1. Place the enable_world_object.prefab at the base of your avatar. This is so the emote animations are correct by default and because a pre-configured limb ik script is directly on the prefab object.
(https://cdn.discordapp.com/attachments/519039794504925186/565367925461221376/install.PNG)
2. Put the Enable World Object and Disable World Object animation clips in your override controller emote slots.
3. Use the emotes in-game.

Guide video: https://youtu.be/1oL1ZNoKBxo