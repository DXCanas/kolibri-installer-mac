#! /bin/bash

# Setting for debug purposes
set -exuo pipefail

mkdir -p whl

# Allows for building directly from pipeline or trigger
if [[ $BUILDKITE_TRIGGERED_FROM_BUILD_ID ]]
then
  echo "--- Downloading whl from triggered build"
  buildkite-agent artifact download "dist/*.whl" . --build $BUILDKITE_TRIGGERED_FROM_BUILD_ID
  mv dist/*.whl whl/
else
  echo "--- Downloading whl from pip"
  pip3 download -d ./whl kolibri
fi

echo "--- Preparing Environment"

echo "Unpacking whl"
# Duped from Android installer's makefile
# Only unpacks kolibri, ignores useless c extensions to reduce size
unzip -q "whl/kolibri*.whl" "kolibri/*" -x "kolibri/dist/cext*" -d src/

# Removing vendored enum package that we don't need
rm -rf ./src/kolibri/dist/enum


echo "Downloading deps"
pipenv sync --dev 

echo "--- Build .app"

# Sets the environment variable needed for the build to find packages in from whl
echo "PYTHONPATH=$PWD/src/kolibri/dist" > .env

# Putting output in file, errors stil log to stderr 
mkdir -p logs
pipenv run pew build | tee logs/full_app_build_log.txt > /dev/null

buildkite-agent artifact upload logs/full_app_build_log.txt

echo "--- :mac: Build .dmg"

pipenv run pew package

echo "--- Uploading"

# Clear dist so that the dmg is in the same dir as the rest of the packages
# dist is may exist because of buildkite-agent download behavior
rm -r dist/* && mv package/osx/kolibri*.dmg dist/

# Environment var doesn't exist my default, so we have to manually pass it.
buildkite-agent artifact upload "dist/kolibri*.dmg" --job $(buildkite-agent meta-data get triggered_from_job_id --default $BUILDKITE_JOB_ID)

# TODO upload directly to google cloud
