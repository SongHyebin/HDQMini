#!/bin/bash
# Enter bash
bash
# You have to change the username. From this point, all instruction can be copy pasted without modifications.
ssh -L 8000:localhost:8000 -L 8080:localhost:5000 hysong@lxplus7.cern.ch
/bin/bash
mkdir -p /tmp/hysong/hdqm
cd /tmp/hysong/hdqm/

git clone -b GG --single-branch
cd CentralHDQM/

# Get an SSO to access OMS and RR APIs. This has to be done before cmsenv script
# First check if we are the owner of the folder where we'll be puting the cookie
if [ $(ls -ld /tmp/$USER/hdqm/CentralHDQM/backend/api/etc | awk '{ print $3 }') == $USER ]; then 
    cern-get-sso-cookie -u https://cmsoms.cern.ch/agg/api/v1/runs -o backend/api/etc/oms_sso_cookie.txt
    cern-get-sso-cookie -u https://cmsrunregistry.web.cern.ch/api/runs_filtered_ordered -o backend/api/etc/rr_sso_cookie.txt
fi

cd backend/
# This will give us a CMSSW environment
source cmsenv

# Add python dependencies
python3 -m pip install -r requirements.txt -t .python_packages/python3
python -m pip install -r requirements.txt -t .python_packages/python2

export PYTHONPATH="${PYTHONPATH}:$(pwd)/.python_packages/python2"

cd extractor/

# Extract few DQM histograms. Using only one process because we are on SQLite
./hdqmextract.py -c cfg/GEM/trendPlotsGEM_all.ini -f afs/cern.ch/user/s/seungjun/public/DQM_V0001_GEM_R000335670.root -j 1
#33번이랑 36번 path 다시 설정하기
# Calculate HDQM values from DQM histograms stored in the DB
./calculate.py -c cfg/GEM/trendPlotsGEM_all.ini -f afs/cern.ch/user/s/seungjun/public/DQM_V0001_GEM_R000335670.root -j 1

# Get the OMS and RR data about the runs
./oms_extractor.py
./rr_extractor.py

cd ../api/
# Run the API
./run.sh &>/dev/null &

cd ../../frontend/
# Use local API instead of the production one
sed -i 's/\/api/http:\/\/localhost:8080\/api/g' js/config.js
# Run the static file server
python3 -m http.server 8000 &>/dev/null &

# Run this to find pids of running servers to kill them:
# ps awwx | grep python
