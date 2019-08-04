#version 150



struct LightDirectional{
	vec3 direction;
	vec3 ambient;
	vec3 diffuse;
	vec3 specular;
};


uniform sampler2D diffuseMap;
uniform vec3 cameraPos;
uniform vec4 AmbientColor;
uniform vec3 viewDir;
uniform bool blinn;
 
in vec3 fragPos;
in vec3 oNormal;
in vec2 oUv0;
 
out vec4 FragColor;

vec3 calculate_light_directional(LightDirectional light, vec3 normal, vec3 view_direcion)
{
	int shininess = 2;
	
	vec3 ambient = light.ambient * vec3(texture(diffuseMap, oUv0));
	vec3 diffuse = light.diffuse * max(dot(normalize(-light.direction), normal), 0) * vec3(texture(diffuseMap, oUv0));
	vec3 specular;
	if(blinn)
		//specular = light.specular * pow(max(dot(normalize(normalize(-light.direction) + normalize(view_direcion)), view_direcion), 0),shininess) * vec3(texture(material.specular0, oUv0));
		specular = light.specular * pow(max(dot(normalize(normalize(-light.direction) + normalize(view_direcion)), view_direcion), 0),shininess);
	else
		//specular = light.specular * pow(max(dot(normalize(reflect(light.direction, normal)), view_direcion), 0),shininess) * vec3(texture(material.specular0, oUv0));
		specular = light.specular * pow(max(dot(normalize(reflect(light.direction, normal)), view_direcion), 0),shininess);
	return ambient + diffuse + specular;
}


//Unlit Ambient
void main() {
     FragColor = texture(diffuseMap, oUv0);
 //   vec3 ambient = AmbientColor.rgb * AmbientColor.a;
   // FragColor = vec4(ambient.rgb * DiffuseColor.rbg , DiffuseColor.a);
	//FragColor = vec4(1.0, 0,0,1.0);
}

void phnonmain()
{
	vec3 camera_Pos = vec3(0.0, 5, 5);
	
	LightDirectional ld;
	ld.direction = vec3(0.0, -1.0, 0.0);
	ld.ambient = vec3(0.3, 0.3, 0.3);
	ld.diffuse = vec3(1.0, 1.0, 1.0);
	ld.specular = vec3(0.5, 0.5, 0.5);
	
	vec3 result = vec3(0.0);
	vec3 normal_normalize = normalize(oNormal);
	//vec3 view_direcion = normalize(camera_Pos - fragPos);
	result += calculate_light_directional(ld, normal_normalize, viewDir);
	
	
	//FragColor = vec4(1.0,0.0,0.0, 1.0);
	FragColor = vec4(result, 1.0);

}
 
