#!/usr/bin/env bash
set -e  # stop immediately if any command fails

echo "Creating cluster - 2 Master,3 workers"
kind create cluster --config kind-config.yml

echo "Waiting for all nodes to be Ready"
kubectl wait --for=condition=Ready nodes --all --timeout=120s

echo "Waiting for ingress-ready label to appear"
until kubectl get nodes -l ingress-ready=true --no-headers 2>/dev/null | grep -q .; do
  sleep 2
done

echo "Installing ingress-nginx"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

echo "Waiting for ingress controller to be ready"
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s

echo "Building React app image"
docker build -t my-react-app:v1 ./my-app

echo "Loading image into cluster nodes"
kind load docker-image my-react-app:v1 --name local-cluster

echo "Applying app manifests (Deployment, Service, Ingress)"
kubectl apply -f react-app.yml

echo "Waiting for app pods to be ready"
kubectl wait --for=condition=Ready pods -l app=react-app --timeout=120s

echo "Done "
