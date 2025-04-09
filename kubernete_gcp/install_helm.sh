#!/usr/bin/env bash

# this is a script to install helm3 on ubuntu 22.04
echo "install helm"
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
bash get_helm.sh

echo "verify helm"
helm version