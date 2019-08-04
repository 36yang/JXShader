#version 150

#ifdef VS_PROGRAM

uniform mat4 worldMat;
uniform mat4 viewprojMat;
uniform mat4 normalMatrix;

in vec4 position;
in vec4 normal;
in vec4 uv0;

out vec4 oUv0;
out vec4 N;
out vec4 v;
 
void main(void)
{
   v = worldMat * position;
   N = normalize(normalMatrix * normal);
  
   oUv0.xy = uv0.xy;

   gl_Position = viewprojMat * v;  
}


#else

uniform vec4 ambientMat;
uniform vec4 diffuseMat;
uniform vec4 specMat;
uniform float specPow;
uniform vec3 light_pos;

uniform sampler2D diffuseMap;

in vec4 oUv0;
in vec4 N;
in vec4 v;

out vec4 fragColour;

void main (void)
{
	vec4 diffuse;
	vec4 spec;
	vec4 ambient;
	
	vec4 texColor = texture(diffuseMap, oUv0.xy);
	texColor = texColor * ambientMat;
 
   vec3 L = normalize(light_pos.xyz - v.xyz);
   vec3 E = normalize(-v.xyz);
   vec3 R = normalize(reflect(-L, N.xyz));  
 
   	ambient = texColor;
 
  	diffuse = clamp( diffuseMat * max(dot(N.xyz, L), 0.0)  , 0.0, 1.0 );
   	spec = clamp ( specMat * pow(max(dot(R,E),0.0),0.3*specPow) , 0.0, 1.0 );
 
	fragColour = ambient + diffuse + spec;
	//fragColour = vec4(1.0, 0,0,1.0);
}


#endif