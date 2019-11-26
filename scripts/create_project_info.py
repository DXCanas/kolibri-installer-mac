import os
import re
import subprocess
from datetime import datetime
from string import Template


def kolibri_version():
    """
    Returns the major.minor version of Kolibri if it exists
    """
    with open('./src/kolibri/VERSION', 'r') as version_file:
        # p4a only likes digits and decimals
        return version_file.read().strip()

def commit_hash():
    """
    Returns the number of commits of the Kolibri mac repo. Returns 0 if something fails.

    TODO hash, unless there's a tag. Use alias to annotate
    """
    repo_dir = os.path.dirname(os.path.abspath(__file__))
    p = subprocess.Popen(
        "git rev-parse --short HEAD",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        shell=True,
        cwd=repo_dir,
        universal_newlines=True
    )
    return p.communicate()[0].rstrip()

def git_tag():
    repo_dir = os.path.dirname(os.path.abspath(__file__))
    p = subprocess.Popen(
        "git tag --points-at {}".format(commit_hash()),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        shell=True,
        cwd=repo_dir,
        universal_newlines=True
    )
    return p.communicate()[0].rstrip()

def mac_app_version():
    """
    Returns the version to be used for the Kolibri mac app.
    Schema: [kolibri version]-[mac installer version or githash]-[build signature type]
    """
    version_indicator = git_tag() or commit_hash()
    return '{}-{}-{}'.format(kolibri_version(), version_indicator, 'unsigned')

def build_number():
    """
    Returns the build number for the app. This is the mechanism used to understand whether one
    build is newer than another. Uses buildkite build number with time as local dev backup
    """
    return os.getenv('BUILDKITE_BUILD_NUMBER', datetime.now().strftime('%y%m%d%H%M'))

def create_project_info():
    """
    Generates project_info.json based on project_info.template
    """
    with open('project_info.template', 'r') as pi_template_file, open('./project_info.json', 'w') as pi_file:
        pi_template = Template(pi_template_file.read())
        pi = pi_template.substitute(mac_app_version=mac_app_version(), build_number=build_number())
        pi_file.write(pi)

create_project_info()
