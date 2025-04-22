
#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=youtubedl
image=tzahi12345/youtubedl-material:latest
port=17442

docker pull ${image}
`dirname $0`/stop-container.sh ${container_name}

docker run -d --name ${container_name} \
--restart=unless-stopped \
--network=traefik --network-alias=${container_name} \
--hostname=${container_name} \
-v /docker_data/${container_name}/appdata:/app/appdata \
-v /docker_data/public/youtube/audio:/app/audio \
-v /docker_data/public/youtube/video:/app/video \
-v /docker_data/public/youtube/subscriptions:/app/subscriptions \
-v /docker_data/public/youtube/users:/app/users \
-m 256M \
-e UID=`id -u` \
-e GID=`id -g` \
-e use_local_db=true \
-e ytdl_url=https://${container_name}.${domain} \
--label "traefik.enable=true" \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
${image}