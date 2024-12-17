#!/bin/bash
docker run --name=watchtower --rm \
-d -v /var/run/docker.sock:/var/run/docker.sock \
--network=traefik containrrr/watchtower -c --run-once $@
