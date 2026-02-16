#!/bin/bash

cd /root/artemis-gke/artemis/
git stash
git fetch
git checkout develop
git reset --hard origin/develop
cat artemis-399212-ee845c76f9ff.json | docker login -u _json_key --password-stdin https://asia-south1-docker.pkg.dev
docker build -t artemis-prod-gke .
docker tag artemis-prod-gke:latest asia-south1-docker.pkg.dev/artemis-399212/artemis-prod-gke/artemis-prod-gke:latest
docker push asia-south1-docker.pkg.dev/artemis-399212/artemis-prod-gke/artemis-prod-gke:latest
kubectl set image deployment/artemis-deployment  artemis-deployment=asia-south1-docker.pkg.dev/artemis-399212/artemis-prod-gke/artemis-prod-gke:latest -n artemis
echo "deploy on K8"
kubectl rollout restart deployment artemis-deployment -n artemis
