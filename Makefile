VPATH = ./dist/

whl/kolibri%.whl:
	# Allows for building directly from pipeline or trigger
ifdef BUILDKITE_TRIGGERED_FROM_BUILD_ID
	@echo "--- Downloading whl from triggered build"
	buildkite-agent artifact download "dist/*.whl" . --build $BUILDKITE_TRIGGERED_FROM_BUILD_ID
	mv dist/*.whl whl/
else
	@echo "--- Downloading whl from pip"
	pip3 download -d ./whl kolibri
endif

src/kolibri: whl/kolibri%.whl
	echo "Unpacking whl"

	# Duped from Android installer's makefile
	# Only unpacks kolibri, ignores useless c extensions to reduce size
	unzip -q "whl/kolibri*.whl" "kolibri/*" -x "kolibri/dist/cext*" "kolibri/dist/enum" -d src/

# Generate the project info file
project_info.json: project_info.template src/kolibri scripts/create_project_info.py
	python ./scripts/create_project_info.py

.env: 
	echo "PYTHONPATH=${PWD}/src/kolibri/dist" > .env

dist/osx/Kolibri.app: project_info.json .env
	pipenv sync --dev 

ifdef BUILDKITE
	mkdir -p logs
	pipenv run pew build &> logs/full_app_build_log.txt
	buildkite-agent artifact upload logs/full_app_build_log.txt
else
	pipenv run pew build
endif

package/osx/kolibri%.dmg: dist/osx/Kolibri.app
	# Clear dist so that the dmg is in the same dir as the rest of the packages
	# dist is may exist because of buildkite-agent download behavior
	pipenv run pew package

ifdef BUILDKITE
	rm -r dist/*
	mv package/osx/kolibri*.dmg dist/
	buildkite-agent artifact upload "dist/kolibri*.dmg" --job $(buildkite-agent meta-data get triggered_from_job_id --default $BUILDKITE_JOB_ID)
endif