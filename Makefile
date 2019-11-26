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

# kolibri%.dmg: VERSION