#version 460 core

uniform FrameInfo {
  mat4 mvp;
} frame_info;

in vec3 position;
in vec2 uv;

out vec2 v_uv;

void main() {
  gl_Position = frame_info.mvp * vec4(position, 1.0);
  v_uv = uv;
}
