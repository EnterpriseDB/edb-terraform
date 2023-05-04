import platform
from collections import namedtuple
import sys
import os
from pathlib import Path
import subprocess
from tempfile import mkstemp
import stat
import json
import textwrap

from edbterraform import __project_name__
from edbterraform.Logger import logger

Version = namedtuple('Version', ['major', 'minor', 'patch'])

def parse_version(version, separator):
    return Version(*[int(x) for x in version.split(separator)])

def join_version(version, separator):
    return separator.join(map(str, version))

def execute_shell(args, environment=os.environ, cwd=None):
    logger.info("Executing command: %s", ' '.join(args))
    logger.debug("environment=%s", environment)
    try:
        process = subprocess.check_output(
            ' '.join(args),
            stderr=subprocess.STDOUT,
            shell=True,
            cwd=cwd,
            env=environment,
        )
        return process
    
    except subprocess.CalledProcessError as e:
        logger.error("Failed to execute the command: %s", e.cmd)
        logger.error("Return code is: %s", e.returncode)
        logger.error("Output: %s", e.output)
        raise Exception(
            "executable seems to be missing. Please install it "
            "or check your PATH variable"
        )


def execute_live_shell(args, environment=os.environ, cwd=None):
    logger.info("Executing command: %s", ' '.join(args))
    logger.debug("environment=%s", environment)
    process = subprocess.Popen(
        ' '.join(args),
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        cwd=cwd,
        env=environment
    )

    rc = 0
    while True:
        output = process.stdout.readline()
        if output:
            logger.info(output.decode("utf-8").strip())
        rc = process.poll()
        if rc is not None:
            break

    return rc

def build_temporary_script(content):
    """
    Generate the installation script as an executable tempfile and returns its
    path.
    """
    script_handle, script_name = mkstemp(suffix='.sh')
    try:
        with open(script_handle, 'w') as f:
            f.write(content)
        st = os.stat(script_name)
        os.chmod(script_name, st.st_mode | stat.S_IEXEC)
        return script_name
    except Exception as e:
        logger.error("Unable to generate the installation script")
        logger.exception(str(e))
        raise Exception("Unable to generate the installation script")

def execute_temporary_script(script_name):
    """
    Execute an installation script
    """
    try:
        output = execute_shell(['/bin/bash', script_name])
        result = output.decode("utf-8")
        os.unlink(script_name)
        logger.debug("Command output: %s", result)
    except subprocess.CalledProcessError as e:
        logger.error("Failed to execute the command: %s", e.cmd)
        logger.error("Return code is: %s", e.returncode)
        logger.error("Output: %s", e.output)
        raise Exception(
            "Failed to execute the following command, please check the "
            "logs for details: %s" % e.cmd
        )

def binary_path(name, bin_path=None):
    """Returns the first seen binary

    Order:
    1. bin_path + name if it exists
    2. PATH + name if it exists
    3. Empty string

    :param name: name of the binary
    :param path: path to the binary
    """
    if bin_path and os.path.exists(bin_path):
        binary_path = os.path.join(bin_path, name)
        if os.path.exists(binary_path) and os.access(binary_path, os.X_OK):
            return binary_path
        
    paths = os.getenv("PATH",'').split(os.pathsep)
    for path in paths:
        binary_path = os.path.join(path, name)
        if os.path.exists(binary_path) and os.access(binary_path, os.X_OK):
            return binary_path    
    
    return ''


class TerraformCLI:
    binary_name = 'terraform'
    min_version = Version(1, 3, 6)
    max_version = Version(1, 4, 0)
    arch_alias = {
        'x86_64': 'amd64',
    }
    DEFAULT_PATH=f'{Path.home()}/.{__project_name__}'

    def __init__(self, binary_dir=None):
        self.bin_dir = binary_dir if binary_dir else TerraformCLI.DEFAULT_PATH
        self.bin_path = os.path.join(self.bin_dir, 'bin')
        self.binary_full_path = os.path.join(self.bin_path, TerraformCLI.binary_name)
        self.architecture = TerraformCLI.arch_alias.get(platform.machine().lower(),platform.machine().lower())
        self.operating_system = platform.system().lower()

    def get_terraform_binary(self):
        return binary_path(TerraformCLI.binary_name, self.bin_path)

    def get_compatible_terraform(self):
        version = self.check_version()
        binary = self.get_terraform_binary()

        if self.min_version > version \
            or version > self.max_version:
            raise subprocess.CalledProcessError(
                cmd=binary,
                output=textwrap.dedent('''
                No compatible version found.
                Min: {min}
                Max: {max}
                Version: {current}
                Binary: {binary}
                ''').format(
                    min = join_version(self.min_version, '.'),
                    max = join_version(self.max_version, '.'),
                    current = join_version(version, '.'),
                    binary = binary
                ),
                returncode=1
            )
        return binary

    def check_version(self):
        try:
            version_keyname = 'terraform_version'
            terraform_path = self.get_terraform_binary()
            command = [terraform_path, '--version', '-json']
            output = execute_shell(
                args=command,
                environment=os.environ.copy(),
            )
            result = json.loads(output.decode("utf-8"))

            version = parse_version(result[version_keyname], '.')
            return version
        except KeyError as e:
            raise e(f'version keyname was not found')
    
    def init_command(self, cwd):
        try:
            terraform_path = self.get_compatible_terraform()
            command = [
                terraform_path,
                'init',
            ]
            output = execute_shell(
                args=command,
                environment=os.environ.copy(),
                cwd=cwd,
            )
        except subprocess.CalledProcessError as e:
            logger.error(f'Error: ({e.output})')
            raise e

    def plan_command(self, cwd):
        try:
            terraform_path = self.get_compatible_terraform()
            command = [
                terraform_path,
                'plan',
                '-input=false',
            ]
            output = execute_shell(
                    args=command,
                    environment=os.environ.copy(),
                    cwd=cwd,
            )
        except subprocess.CalledProcessError as e:
            logger.error(f'Error: ({e.output})')
            raise e

    def apply_target_command(self, cwd):
        try:
            terraform_path = self.get_compatible_terraform()
            command = [
                terraform_path,
                'apply',
                '-input=false',
                '-target=null_resource.validation',
                '-auto-approve',
            ]
            output = execute_shell(
                    args=command,
                    environment=os.environ.copy(),
                    cwd=cwd,
            )
        except subprocess.CalledProcessError as e:
            logger.error(f'Error: ({e.output})')
            raise e

    @classmethod
    def get_max_version(cls):
        return join_version(cls.max_version, '.')

    def install(self):
        installation_script = textwrap.dedent('''
            #!/bin/bash
            set -eu

            rm -rf {path}/terraform/{version}/bin
            rm -f /tmp/terraform.zip
            rm -f {path}/bin/terraform

            mkdir -p {path}/bin
            mkdir -p {path}/terraform/{version}/bin
            wget -q https://releases.hashicorp.com/terraform/{version}/terraform_{version}_{os_flavor}_{arch}.zip -O /tmp/terraform.zip
            unzip /tmp/terraform.zip -d {path}/terraform/{version}/bin
            ln -sf {path}/terraform/{version}/bin/terraform {path}/bin/.
        ''')

        terraform_bin = self.get_terraform_binary()
        # Skip installation if latest already installed
        if terraform_bin == self.binary_full_path \
            and join_version(self.check_version(), '.') == self.get_max_version():
            return

        script_name = build_temporary_script(
            installation_script.format(
                path=self.bin_dir,
                version=self.get_max_version(),
                os_flavor=self.operating_system,
                arch=self.architecture,
            )
        )

        execute_temporary_script(script_name)
