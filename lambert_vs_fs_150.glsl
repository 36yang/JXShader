#version 150

#ifdef VS_PROGRAM


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

#else

struct LightDirectional{
	vec3 direction;
	vec3 ambient;
	vec3 diffuse;
	vec3 specular;
};


uniform sampler2D diffuseMap;
uniform vec3 cameraPos;
uniform vec4 AmbientColor;
uniform vec3 vireDir;
uniform bool blinn;
 
in vec3 fragPos;
in vec3 oNormal;
in vec2 oUv0;
 
out vec4 FragColor;

vec3 calculate_light_directional(LightDirectional light, vec3 normal, vec3 view_direcion)
{

	vec3 ambient = AmbientColor.rgb * vec3(texture(diffuseMap, oUv0));
	vec3 diffuse = light.diffuse * max(dot(normalize(-light.direction), normal), 0) * vec3(texture(diffuseMap, oUv0));
	return ambient + diffuse;
}


void main()
{
	vec3 camera_Pos = vec3(0.0, 5, 5);
	
	LightDirectional ld;
	ld.direction = vec3(1.0, -1.0, 1.0);
	ld.ambient = vec3(0.3, 0.3, 0.3);
	ld.diffuse = vec3(1.0, 1.0, 1.0);
	ld.specular = vec3(0.5, 0.5, 0.5);
	
	vec3 result = vec3(0.0);
	vec3 normal_normalize = normalize(oNormal);
	//vec3 view_direcion = normalize(camera_Pos - fragPos);
	result += calculate_light_directional(ld, normal_normalize, vireDir);
	
	
	//FragColor = vec4(1.0,0.0,0.0, 1.0);
	FragColor = vec4(result, 1.0);

}
 



#endif