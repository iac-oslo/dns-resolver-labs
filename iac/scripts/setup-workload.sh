#!/bin/bash
set -e

apt-get clean
apt-get update -y || apt-get update -y
apt-get install -y software-properties-common
add-apt-repository -y universe
apt-get update -y || apt-get update -y
apt-get install -y dnsutils curl
