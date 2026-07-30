import sys

filepath = 'tardis.tscn'
with open(filepath, 'r') as f:
    content = f.read()

# Create the Solid Blue Material
solid_blue = """[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_BlueSolid"]
albedo_color = Color(0.1, 0.2, 0.5, 1)
roughness = 0.5
"""

# Replace the textured blue material definition with both
content = content.replace('[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_Blue"]\n'
                          'albedo_texture = ExtResource("2_tardis_side")\n'
                          'roughness = 0.5\n'
                          'uv1_scale = Vector3(1, 1, 1)', 
                          solid_blue + '\n' +
                          '[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_Panels"]\n'
                          'albedo_texture = ExtResource("2_tardis_side")\n'
                          'emission_enabled = true\n'
                          'emission_energy_multiplier = 2.0\n'
                          'emission_texture = ExtResource("2_tardis_side")\n'
                          'roughness = 0.5\n'
                          'uv1_scale = Vector3(1, 1, 1)')

# Change Visuals override to Solid Blue
content = content.replace('material_override = SubResource("StandardMaterial3D_Blue")',
                          'material_override = SubResource("StandardMaterial3D_BlueSolid")')

# Add the 4 Face decals
faces = """
[node name="FaceFront" type="CSGBox3D" parent="Visuals"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.5, 0.701)
size = Vector3(1.3, 2.6, 0.01)
material = SubResource("StandardMaterial3D_Panels")

[node name="FaceBack" type="CSGBox3D" parent="Visuals"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.5, -0.701)
size = Vector3(1.3, 2.6, 0.01)
material = SubResource("StandardMaterial3D_Panels")

[node name="FaceLeft" type="CSGBox3D" parent="Visuals"]
transform = Transform3D(-4.37114e-08, 0, 1, 0, 1, 0, -1, 0, -4.37114e-08, -0.701, 1.5, 0)
size = Vector3(1.3, 2.6, 0.01)
material = SubResource("StandardMaterial3D_Panels")

[node name="FaceRight" type="CSGBox3D" parent="Visuals"]
transform = Transform3D(-4.37114e-08, 0, -1, 0, 1, 0, 1, 0, -4.37114e-08, 0.701, 1.5, 0)
size = Vector3(1.3, 2.6, 0.01)
material = SubResource("StandardMaterial3D_Panels")

[node name="Roof1" type="CSGBox3D" parent="Visuals"]"""

content = content.replace('[node name="Roof1" type="CSGBox3D" parent="Visuals"]', faces)

with open(filepath, 'w') as f:
    f.write(content)
