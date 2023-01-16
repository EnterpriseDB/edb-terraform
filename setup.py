import os.path
import sys

from setuptools import setup
from textwrap import dedent

def get_version():
    cur_dir = os.path.dirname(__file__)
    init_path = os.path.join(cur_dir, "edbterraform", "__init__.py")

    with open(init_path) as f:
        for line in f:
            if line.startswith("__version__"):
                return line.split('"')[1]
    raise Exception("Version information not found in %s" % init_path)

def get_long_description():
    cur_dir = os.path.dirname(__file__)
    with open(os.path.join(cur_dir, "README.md")) as f:
        return f.read()

setup(
    name="edb-terraform",
    version=get_version(),
    author="EDB",
    author_email="edb-devops@enterprisedb.com",
    packages=[
        "edbterraform",
    ],
    url="https://github.com/EnterpriseDB/edb-terraform/",
    entry_points = {
        'console_scripts': [
            'edb-terraform = edbterraform.lib:new_project_main',
        ]
    },
    license="BSD",
    description=dedent("""
    Terraform templates aimed to provide easy to use YAML configuration file
    describing the target cloud infrastrure.
    """),
    long_description=get_long_description(),
    long_description_content_type="text/markdown",
    classifiers=[
        "Development Status :: 5 - Production/Stable",
        "Environment :: Console",
        "License :: OSI Approved :: BSD License",
        "Programming Language :: Python :: 3",
        "Topic :: Database",
    ],
    keywords="terraform cloud yaml edb cli aws rds aurora azure aks gcloud gke",
    python_requires=">=3.6",
    install_requires=["PyYAML>=5.1", "cryptography", "jinja2"],
    extras_require={},
    data_files=[],
    package_data={
        'edbterraform': [
            'data/terraform/*/variables.tf',
            'data/terraform/*/modules/*/*.tf',
            'data/terraform/*/modules/*/*.sh',
            'data/templates/*/*',
        ]
    }
)
