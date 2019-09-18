#version 150

#ifdef VS_PROGRAM

in vec4 position;
in vec3 normal;
in vec4 uv0;
#ifdef NORMAL_MAP
in vec3 tangent;
out vec4 oUv0;
out vec4 oTangent;
#else
out vec2 oUv0;
#endif
out vec3 fragPos;
out vec3 oNormal;

uniform mat4 modelMat;
uniform mat4 it_worldMat;
uniform mat4 worldViewProjMat;

#ifdef RECEIVE_SHADOW_PSSM
uniform mat4 texWVPMat0;
uniform mat4 texWVPMat1;
out vec4 oLightPosition0;
out vec4 oLightPosition1;
out float zPosition;
#endif


void main()
{
    fragPos = vec3(modelMat * position);
   
#ifdef NORMAL_MAP
    oNormal = normalize (vec3(it_worldMat * vec4(normal, 0)));	
    vec3 wTangent = normalize(vec3(it_worldMat * vec4(tangent, 0)));  //转到世界空间
    vec3 wBiTangent = cross(oNormal, wTangent);
    oUv0 = vec4(uv0.xy, wBiTangent.xy);
    oTangent = vec4(wTangent.xyz, wBiTangent.z);
#else
    oNormal = vec3(it_worldMat * vec4(normal, 1));
    oUv0 = uv0.xy;
#endif

	gl_Position = worldViewProjMat * position;
	
#ifdef RECEIVE_SHADOW_PSSM
	zPosition = gl_Position.z;
	oLightPosition0 = texWVPMat0 * position;
	oLightPosition1 = texWVPMat1 * position;
#endif
	
}

#else

uniform vec4 AmbientColor;    //ambient RGBA -- alpha is intensity

uniform vec4 diffuseMat;   //材质属性
uniform vec4 specularMat;  //反射光属性 RGBA --alpha表示高光强度 
uniform vec4 ambientMat;   //漫反射材质属性
uniform vec4 emissiveMat;  //伪自发光材质属性

uniform int light_count;    //实际灯光数量
uniform int light_type_array[MAX_LIGHT_COUNT];  //灯光类型 LT_POINT = 0, LT_DIRECTIONAL = 1, LT_SPOTLIGHT = 2
uniform vec4 light_diffuse_array[MAX_LIGHT_COUNT];   //灯光颜色
uniform float light_power_array[MAX_LIGHT_COUNT];   //灯光强度
uniform vec3 light_direction_array[MAX_LIGHT_COUNT];  //平行光和聚光灯
uniform vec3 light_position_array[MAX_LIGHT_COUNT];
  //Attenuation = Constant + Linear * Distance + Quadratic * Distance ^ 2
  //Luminosity = 1 / Attenuation
uniform vec4 light_attenuation_array[MAX_LIGHT_COUNT]; //点光源，聚光灯衰减，平行光无效，
uniform vec2 spotlight_params_array[MAX_LIGHT_COUNT]; //聚光灯外角cos值和内角cos值 outcutoff|cutoff


uniform sampler2D diffuseMap;
uniform float minAlpha;
#ifdef NORMAL_MAP
uniform sampler2D normalMap;
in vec4 oUv0;
in vec4 oTangent;
#endif
in vec2 oUv0;

#ifdef SPECULAR_MAP
uniform sampler2D specularMap;
#endif
#ifdef AO_MAP
uniform sampler2D aoMap;
#endif

uniform vec3 cameraPos;

in vec3 fragPos;
in vec3 oNormal;

#ifdef RECEIVE_SHADOW_PSSM
in vec4 oLightPosition0;
in vec4 oLightPosition1;
in float zPosition;
uniform sampler2D shadowMap0;
uniform sampler2D shadowMap1;
uniform vec4 invShadowMapSize0;
uniform vec4 invShadowMapSize1;
uniform vec4 pssmSplitPoints;

float shadowPCF(in sampler2D shadowMap, vec4 shadowMapPos, vec2 offset)
{
	shadowMapPos = shadowMapPos / shadowMapPos.w;
	vec2 uv = shadowMapPos.xy;
	vec3 o = vec3(offset, -offset.x) * 0.49f;;

   // float c = texture(shadowMap, uv.xy).r;
	//float c =	(shadowMapPos.z <= texture(shadowMap, uv.xy).r) ? 1 : 0; // top left
	
	float c =	(shadowMapPos.z <= texture(shadowMap, uv.xy - o.xy).r) ? 1 : 0; // top left
	c +=		(shadowMapPos.z <= texture(shadowMap, uv.xy + o.xy).r) ? 1 : 0; // bottom right
	c +=		(shadowMapPos.z <= texture(shadowMap, uv.xy + o.zy).r) ? 1 : 0; // bottom left
	c +=		(shadowMapPos.z <= texture(shadowMap, uv.xy - o.zy).r) ? 1 : 0; // top right
	return c / 4;
	//return c;
}

#endif


vec3 expand(vec3 v)
{
	return (v - 0.5) * 2.0;
}


out vec4 FragColor;
void main()
{

	vec4 diffuseColor = texture(diffuseMap, oUv0.xy);
	if(diffuseColor.a < minAlpha) {discard;}

    vec3 viewDir = normalize(fragPos - cameraPos);
	vec3 normal;
	#ifdef NORMAL_MAP
		vec3 tnormal = expand(texture(normalMap, oUv0.xy).rgb);
		normal.x = dot(vec3(oTangent.x, oUv0.z, oNormal.x), tnormal);
		normal.y = dot(vec3(oTangent.y, oUv0.w, oNormal.y), tnormal);
		normal.z = dot(vec3(oTangent.z, oTangent.w, oNormal.z), tnormal);
        normal = normalize(normal);
    #else
        normal = normalize(oNormal);
	#endif
	 
	#ifdef AO_MAP
		vec4 aoColor = texture(aoMap, oUv0.xy);
	#endif

float shadowing = 1.0f;
#ifdef RECEIVE_SHADOW_PSSM
 if(light_type_array[0] == 1)  //平行光
 {
	vec3 meshNormal = normalize(oNormal);
	vec3 lightdir = light_direction_array[0];
	shadowing = abs(dot(meshNormal, lightdir));
	#define SELFSHADOW_COS_MAX 0.01745240643728 //cos 89 degree
	if ( shadowing > SELFSHADOW_COS_MAX )
	{
		if (zPosition <= pssmSplitPoints.y)
		{
			//splitColour = vec4(0.5, 0, 0, 1);
			shadowing = shadowPCF(shadowMap0, oLightPosition0, invShadowMapSize0.xy);
		}
		else if(zPosition <= pssmSplitPoints.z)
		{
			shadowing = shadowPCF(shadowMap1, oLightPosition1, invShadowMapSize1.xy);
		}
		else
		{
			shadowing = 1.0f;
		}
	}
	shadowing = shadowing + 0.35f;   //环境光0.35f， 阴影至少是环境光
 } 
#endif
	
	#ifdef AO_MAP
		vec3 ambient = emissiveMat.rgb + AmbientColor.rgb * ambientMat.rgb * aoColor.rgb * diffuseColor.rgb;;
	#else
		vec3 ambient = emissiveMat.rgb + AmbientColor.rgb * ambientMat.rgb * diffuseColor.rgb;;
	#endif
    vec3 result = ambient;
    for(int i=0 ; i<light_count; i++)
    {
        if(light_type_array[i] == 1) //平行光
        {
		
			if(shadowing >= 1.0f)  //不在阴影中正常光照
			{
				shadowing = 1.0f;
				
				vec3 diffuse =  light_diffuse_array[i].rgb * diffuseMat.rgb * max(dot(normalize(-light_direction_array[i]), normal), 0);
				#ifdef LAMBERT
					 result = result + diffuse * diffuseColor.rgb;
				#else
					vec3 specular;
					#ifdef BLINN_PHONE
						#ifdef SPECULAR_MAP
							specular = specularMat.rgb * pow(max(dot(normalize(normalize(-light_direction_array[i]) + viewDir), normal), 0), specularMat.a) * vec3(texture(specularMap, oUv0.xy));    
						#else
							specular = specularMat.rgb * pow(max(dot(normalize(normalize(-light_direction_array[i]) + viewDir), normal), 0), specularMat.a);
						#endif
					#else
						#ifdef SPECULAR_MAP
							specular = specularMat.rgb * pow(max(dot(normalize(reflect(-light_direction_array[i], normal)), viewDir), 0),specularMat.a) * vec3(texture(specularMap, oUv0.xy));                    
						#else
							specular = specularMat.rgb * pow(max(dot(normalize(reflect(-light_direction_array[i], normal)), viewDir), 0), specularMat.a);
						#endif
					#endif
					 result = result + (diffuse + specular) * diffuseColor.rgb;
					  //  result = result + diffuse + specular;
						// result = result + ambient + diffuse;
				#endif
				
			} 
			else 
			{
				vec3 diffuse =  AmbientColor.rgb * diffuseMat.rgb * max(dot(normalize(-light_direction_array[i]), normal), 0);
				result = result + diffuse * diffuseColor.rgb;
				
				//result = vec3(0.5,0.5,0.5) * diffuseColor.rgb;
			}
        }
        else if(light_type_array[i] == 0) //点光源
        {  
            vec3 light_dir = light_position_array[i] - fragPos;
			float dis = length(light_dir);
			light_dir = normalize(light_dir);
            float attenuation = 1/(light_attenuation_array[i].g +light_attenuation_array[i].b * dis + light_attenuation_array[i].a * dis * dis); 
            vec3 diffuse = light_diffuse_array[i].rgb * diffuseMat.rgb * max(dot(light_dir, normal), 0);
            #ifdef LAMBERT
                 result = result + attenuation * diffuse * diffuseColor.rgb;
            #else
                vec3 specular;
                #ifdef BLINN_PHONE
                    #ifdef SPECULAR_MAP
						specular = specularMat.rgb * pow(max(dot(normalize(light_dir + viewDir), normal), 0), specularMat.a) * vec3(texture(specularMap, oUv0.xy));  
                    #else
                        specular = specularMat.rgb * pow(max(dot(normalize(light_dir + normalize(viewDir)), normal), 0), specularMat.a);
                    #endif
                #else
                    #ifdef SPECULAR_MAP
						specular = specularMat.rgb * pow(max(dot(normalize(reflect(light_dir, normal)), viewDir), 0), specularMat.a) * vec3(texture(specularMap, oUv0.xy));
                    #else
                        specular = specularMat.rgb * pow(max(dot(normalize(reflect(light_dir, normal)), viewDir), 0), specularMat.a);
                    #endif
                #endif
                result = result + attenuation * (diffuse + specular) * diffuseColor.rgb;
				//result = result + ambient + diffuse + specular;
				//result = vec3(1.0, 0, 0);
            #endif
        }
        else if(light_type_array[i] == 2) //聚光灯
        {
            vec3 light_dir =  light_position_array[i] - fragPos;
			float dis = length(light_dir);
			light_dir = normalize(light_dir);
            float attenuation = 1/(light_attenuation_array[i].g +light_attenuation_array[i].b * dis + light_attenuation_array[i].a * dis * dis); 
            float theta = dot(light_dir, normalize(light_direction_array[i]));
            if(theta < spotlight_params_array[i][0])
            {
                vec3 diffuse = light_diffuse_array[i].rgb * diffuseMat.rgb * max(dot(light_dir, normal), 0.0f);
                #ifdef LAMBERT
					float intensity=clamp((spotlight_params_array[i][1] - theta)/(spotlight_params_array[i][1]-spotlight_params_array[i][0]),0.0,1.0); //我们不希望强度值在0与1之外
                     result = result + attenuation * intensity * diffuse * diffuseColor.rgb;
                #else
                    vec3 specular;
                    #ifdef BLINN_PHONE
                        #ifdef SPECULAR_MAP
							specular = specularMat.rgb * pow(max(dot(normalize(light_dir + viewDir), normal), 0.0f), specularMat.a) * vec3(texture(specularMap, oUv0.xy));  
						#else
                            specular= specularMat.rgb * pow(max(dot(normalize(light_dir + viewDir), normal), 0.0f), specularMat.a);
                        #endif
                    #else
                        #ifdef SPECULAR_MAP
							pecular= specularMat.rgb * pow(max(dot(normalize(reflect(light_dir, normal)), viewDir), 0.0f), specularMat.a) * vec3(texture(specularMap, oUv0.xy));   
                        #else
                            specular= specularMat.rgb * pow(max(dot(normalize(reflect(light_dir, normal)), viewDir), 0.0f), specularMat.a);
                        #endif
                    #endif
					float intensity=clamp((spotlight_params_array[i][1] - theta)/(spotlight_params_array[i][1]-spotlight_params_array[i][0]),0.0,1.0); //我们不希望强度值在0与1之外
                   result = result + attenuation * intensity * (diffuse + specular) * diffuseColor.rgb;
                #endif
            }
        }
     }
	 


//#ifdef FOG_LINEAR
	////float fog = ( fogParams.z - eyeDistance ) * fogParams.w; // / ( fogParams.z - fogParams.y );
	//float fog = ( 100 - uv.z ) * 0.01;
	//float4 fogColor;
	//fogColor.r = 0.8; fogColor.g = 0.8; fogColor.b = 1.0;
	//oColour.rgb += fogColor.rgb * (1.0 - fog);
//#endif
	
	 
	//FragColor = vec4(1.0,0.0,0.0, 1.0);
	FragColor = vec4(result, diffuseColor.a);
}
 

#endif