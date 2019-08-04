#version 150
in vec4 position;
in vec3 normal;
in vec4 uv0;

out vec3 fragPos;
out vec3 oNormal;
out vec2 oUv0;

uniform mat4 modelMat;
uniform mat4 it_worldMat;
uniform mat4 worldViewProjMat;

void main()
{
   
    fragPos = vec3(modelMat * position);
    oNormal = vec3(it_worldMat * vec4(normal, 1));
    oUv0 = uv0.xy;
	gl_Position = worldViewProjMat * position;
}