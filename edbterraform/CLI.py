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
from typing import Union

from edbterraform import __dot_project__
from edbterraform.utils.logs import logger

Version = namedtuple('Version', ['major', 'minor', 'patch'])

def parse_version(version, separator='.'):
    return Version(*[int(x) for x in version.split(separator)])

def join_version(version, separator='.'):
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
        logger.error("Command failed: %s", e.cmd)
        logger.error("Return code: %s", e.returncode)
        logger.error("Output: %s", e.output)
        raise Exception(
            "If executable fails to execute, check the path."
            "If options --destroy or --apply fail, manual intervention may be required to allow for a recovery."
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
    # Version temporarily locked to 1.5.5
    # Ref PR: https://github.com/EnterpriseDB/edb-terraform/pull/88
    max_version = Version(1, 5, 5)
    arch_alias = {
        'x86_64': 'amd64',
    }
    DEFAULT_PATH = __dot_project__
    plan_file = 'terraform.plan'

    def __init__(self, binary_dir=None, version=None):
        self.bin_dir = binary_dir if binary_dir else self.DEFAULT_PATH
        self.version = self.get_max_version() if not version else version
        self.bin_path = f'{self.bin_dir}/terraform/{self.version}/bin' if self.bin_dir == self.DEFAULT_PATH else os.path.join(self.bin_dir, 'bin')
        self.binary_full_path = os.path.join(self.bin_path, self.binary_name)
        self.architecture = self.arch_alias.get(platform.machine().lower(),platform.machine().lower())
        self.operating_system = platform.system().lower()

    def get_terraform_binary(self):
        return binary_path(self.binary_name, self.bin_path)

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
                f'-out={self.plan_file}'
            ]
            output = execute_shell(
                    args=command,
                    environment=os.environ.copy(),
                    cwd=cwd,
            )
        except subprocess.CalledProcessError as e:
            logger.error(f'Error: ({e.output})')
            raise e

    def apply_command(self, cwd, validate_only=False):
        try:
            terraform_path = self.get_compatible_terraform()
            command = [terraform_path, 'apply', '-input=false', '-auto-approve',]
            if validate_only:
                command.append('-target=null_resource.validation')
            command.append(self.plan_file)
            output = execute_shell(
                    args=command,
                    environment=os.environ.copy(),
                    cwd=cwd,
            )
        except subprocess.CalledProcessError as e:
            logger.error(f'Error: ({e.output})')
            raise e

    def destroy_command(self, cwd):
        '''
        Attempt to destroy resources.
        If previously destroyed, a second attempt will fail with our custom modules,
          and instead requires checking of the state to confirm destruction.
        Some destructions will require manual intervention if state is left incomplete.
        In most cases, we are able to comment out the codesection 
          or use the Terraform cli to attempt to remove the problem resource from the state.
        If a user deletes their statefile, they will need to visit the providers GUI and manually destroy any remaining resources.
        '''
        try:
            cwd = Path(cwd)
            if not cwd.exists():
                logger.info('path does not exist yet, no destruction needed')
                return False

            if not (cwd / 'terraform.tfstate').exists():
                raise IOError('terraform.tfstate not found.')

            if (cwd / 'terraform.tfstate').stat().st_size == 0:
                logger.info('terraform.tfstate is empty, no destruction needed')
                return True

            terraform_path = self.get_compatible_terraform()
            command = [terraform_path, 'state', 'list',]
            output = execute_shell(
                    args=command,
                    environment=os.environ.copy(),
                    cwd=cwd,
            )

            if len(output.decode("utf-8").split('\n'))-1 == 0:
                logger.info('state list return 0 results, no destruction needed')
                return True

            command = [terraform_path, 'destroy', '-input=false', '-auto-approve',]
            output = execute_shell(
                    args=command,
                    environment=os.environ.copy(),
                    cwd=cwd,
            )
        except subprocess.CalledProcessError as e:
            logger.error(f'Error: ({e.output})')
            raise e

        return True

    @classmethod
    def get_max_version(cls):
        return join_version(cls.max_version, '.')

    def install(self):
        installation_script = textwrap.dedent('''
            #!/bin/bash
            set -eu

            rm -rf {full_path}
            rm -f /tmp/terraform.zip

            mkdir -p {bin_path}
            wget -q https://releases.hashicorp.com/terraform/{version}/terraform_{version}_{os_flavor}_{arch}.zip -O /tmp/terraform.zip
            unzip /tmp/terraform.zip -d {bin_path}
        ''')

        if self.version == "0":
            logger.info('Terraform 0 version used, skipping installation')
            return

        terraform_bin = self.get_terraform_binary()
        # Skip installation if version is already installed
        if terraform_bin == self.binary_full_path \
            and join_version(self.check_version()) == self.version:
            logger.info(f'Terraform {self.version} is already installed')
            return

        script_name = build_temporary_script(
            installation_script.format(
                bin_path=self.bin_path,
                full_path=self.binary_full_path,
                version=self.version,
                os_flavor=self.operating_system,
                arch=self.architecture,
            )
        )

        logger.info(f'Installing Terraform {self.version} in {self.binary_full_path}')
        execute_temporary_script(script_name)

class JqCLI:
    binary_name = 'jq'
    min_version = Version(1, 6, 0)
    max_version = Version(1, 7, 1)
    arch_alias = {
        'x86_64': 'amd64',
    }
    DEFAULT_PATH = __dot_project__

    def __init__(self, binary_dir=None, version=None):
        self.bin_dir = binary_dir if binary_dir else self.DEFAULT_PATH
        self.version = self.get_max_version() if not version else version
        self.bin_path = f'{self.bin_dir}/jq/{self.version}/bin' if self.bin_dir == self.DEFAULT_PATH else os.path.join(self.bin_dir, 'bin')
        self.binary_full_path = os.path.join(self.bin_path, self.binary_name)
        self.architecture = self.arch_alias.get(platform.machine().lower(),platform.machine().lower())
        self.operating_system = platform.system().lower()

    @classmethod
    def format_version(cls, version: Union[Version, str]) -> str:
        '''
        JQ drops the patch number when it is 0

        Returned as a version string
        '''
        # Convert Version tuple to string
        if isinstance(version, Version):
            version = join_version(version)

        versions = version.split('.')
        if len(versions) <= 2 or versions[2] == '0':
            return '.'.join(versions[:2])

        return version

    @classmethod
    def get_max_version(cls):
        return join_version(cls.max_version)

    @classmethod
    def get_min_version(cls):
        return join_version(cls.min_version)

    def check_version(self):
        try:
            jq_path = self.get_jq_binary()
            jq_prefix = "jq-" # jq --version returns a single string as jq-<version> and newline
            command = [jq_path, '--version']
            output = execute_shell(
                args=command,
                environment=os.environ.copy(),
            )
            result = output.decode("utf-8")
            return result.lstrip(jq_prefix).rstrip("\n\s")
        except KeyError as e:
            raise e(f'version keyname was not found')

    def get_jq_binary(self):
        return binary_path(self.binary_name, self.bin_path)

    def install(self):
        installation_script = textwrap.dedent('''
            #!/bin/bash
            set -eu

            rm -rf {full_path}
            mkdir -p {bin_path}

            wget -q https://github.com/jqlang/jq/releases/download/jq-{version}/jq-{os_flavor}-{arch} -O {full_path}
            chmod +x {full_path}
        ''')

        if self.version == "0":
            logger.info('JQ 0 version used, skipping installation')
            return

        jq_bin = self.get_jq_binary()
        # Skip installation if latest already installed
        if jq_bin == self.binary_full_path \
            and self.check_version() == self.version:
            logger.info(f'JQ {self.version} is already installed')
            return

        script_name = build_temporary_script(
            installation_script.format(
                bin_path=self.bin_path,
                full_path=self.binary_full_path,
                version=self.format_version(self.version),
                os_flavor=self.operating_system,
                arch=self.architecture,
            )
        )

        logger.info(f'Installing JQ {self.version} in {self.binary_full_path}')
        execute_temporary_script(script_name)
