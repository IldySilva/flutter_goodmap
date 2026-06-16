#version 460 core

uniform sampler2D atlas;

in vec2 v_uv;
out vec4 frag_color;

void main() {
  frag_color = texture(atlas, v_uv);
}
