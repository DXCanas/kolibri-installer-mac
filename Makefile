.PHONY = macapp clean

clean:
	rm -rf whl dist package src/kolibri project_info.json .env

whl/kolibri*.whl:
	mkdir -p whl
	# Allows for building directly from pipeline or trigger
ifdef BUILDKITE_TRIGGERED_FROM_BUILD_ID
	@echo "--- Downloading whl from triggered build"
	buildkite-agent artifact download "dist/*.whl" . --build $BUILDKITE_TRIGGERED_FROM_BUILD_ID
	mv dist/*.whl whl/
else
	@echo "--- Downloading whl from pip"
	pip3 download -d ./whl kolibri
endif

src/kolibri: whl/kolibri*.whl
	@echo "--- Unpacking whl"

	# Duped from Android installer's makefile
	# Only unpacks kolibri, ignores useless c extensions to reduce size
	unzip -q "whl/kolibri*.whl" "kolibri/*" -x "kolibri/dist/cext*" "kolibri/dist/enum" -d src/

.env: 
	echo "PYTHONPATH=$$PWD/src/kolibri/dist" > .env

dist/osx/Kolibri.app: project_info.json .env
	@echo "--- Downloading Python deps"
	pipenv sync --dev 

	@echo "--- Building app"
ifdef BUILDKITE
	mkdir -p logs
	pipenv run pew build &> logs/full_app_build_log.txt

	@echo "Uploading logs"
	buildkite-agent artifact upload logs/full_app_build_log.txt
else
	pipenv run pew build
endif

package/osx/kolibri*.dmg: dist/osx/Kolibri.app
	@echo "--- :mac: Packaging .dmg"
	pipenv run pew package

ifdef BUILDKITE
	# Clear dist so that the dmg is in the same dir as the rest of the packages
	# dist is may exist because of buildkite-agent download behavior
	rm -r dist/*
	mv package/osx/kolibri*.dmg dist/kolibri-$$(more src/kolibri/VERSION)-$$(git rev-parse --short HEAD).dmg

	@echo "--- Uploading .dmg"

	# Environment var doesn't exist my default, so we have to manually pass it.
	buildkite-agent artifact upload "dist/kolibri*.dmg" --job $$(buildkite-agent meta-data get triggered_from_job_id --default $$BUILDKITE_JOB_ID)
endif

macapp: package/osx/kolibri*.dmg
