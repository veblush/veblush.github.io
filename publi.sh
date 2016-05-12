#!/usr/bin/env bash

rm -rf _site
jekyll build

export GIT_DEPLOY_DIR=_site
export GIT_DEPLOY_BRANCH=master
./deploy.sh
