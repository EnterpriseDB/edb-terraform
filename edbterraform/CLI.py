import platform
from collections import namedtuple
import sys
import os
from pathlib import Path
import shutil
from urllib import request as Request
import subprocess
import json
import textwrap
from typing import Union

from edbterraform import __dot_project__
from edbterraform.utils.logs import logger
from edbterraform.utils.files import checksum_verify
from edbterraform.utils.script import execute_shell, binary_path

Version = namedtuple('Version', ['major', 'minor', 'patch'])

def parse_version(version, separator='.'):
    return Version(*[int(x) for x in version.split(separator)])

def join_version(version, separator='.'):
    return separator.join(map(str, version))

class TerraformCLI:
    binary_name = 'terraform'
    min_version = Version(1, 3, 6)
    # Version temporarily locked to 1.5.5
    # Ref PR: https://github.com/EnterpriseDB/edb-terraform/pull/88
    max_version = Version(1, 5, 5)
    arch_alias = {
        'x86_64': 'amd64',
    }
    DOT_PATH = __dot_project__
    plan_file = 'terraform.plan'

    def __init__(self, binary_dir=None, version=None):
        self.bin_dir = binary_dir if binary_dir else self.DOT_PATH
        self.skip_install = str(version) == "0"
        self.version = self.get_max_version() if not version or self.skip_install else version
        self.default_path = f'{self.bin_dir}/{self.binary_name}/{self.version}/bin'
        self.bin_path = self.default_path if self.bin_dir == self.DOT_PATH else os.path.join(self.bin_dir, 'bin')
        self.binary_full_path = os.path.join(self.bin_path, self.binary_name)
        self.architecture = self.arch_alias.get(platform.machine().lower(),platform.machine().lower())
        self.operating_system = platform.system().lower()

    def get_binary(self):
        return binary_path(self.binary_name, self.bin_path, self.default_path)

    def get_compatible_terraform(self):
        version = self.check_version()
        binary = self.get_binary()

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
            terraform_path = self.get_binary()
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

    @classmethod
    def get_min_version(cls):
        return join_version(cls.min_version)

    def install(self):
        if self.skip_install:
            logger.info('Terraform 0 version used, skipping installation')
            return

        terraform_bin = self.get_binary()
        # Skip installation if version is already installed
        if terraform_bin == self.binary_full_path \
            and join_version(self.check_version()) == self.version:
            logger.info(f'Terraform {self.version} is already installed')
            return

        try:
            logger.info(f'Installing Terraform {self.version} in {self.binary_full_path}')
            full_path = Path(self.binary_full_path)
            full_path.unlink(missing_ok=True)
            bin_path = Path(self.bin_path)
            bin_path.mkdir(parents=True, exist_ok=True)

            base = f'https://releases.hashicorp.com/terraform/{self.version}/terraform_{self.version}'
            source_url = base + f'_{self.operating_system}_{self.architecture}.zip'
            zip_file = Path(Request.urlretrieve(source_url)[0])

            # Get sha256 checksum file
            checksum_url = base + f'_SHA256SUMS'
            checksum_file = Path(Request.urlretrieve(checksum_url)[0])

            # Verify checksum
            if not checksum_verify(zip_file, checksum_file, 'sha256'):
                checksum_file.unlink(missing_ok=True)
                zip_file.unlink(missing_ok=True)
                raise Exception(f'Failed to verify Terraform {self.version} checksum')
            logger.info(f'Verified Terrafrom {self.version} checksum')
            checksum_file.unlink(missing_ok=True)

            shutil.unpack_archive(zip_file, bin_path, 'zip')
            zip_file.unlink(missing_ok=True)
            full_path.chmod(0o770)
        except Exception as e:
            raise Exception(f'Failed to install Terraform {self.version} - ({e})') from e


class JqCLI:
    binary_name = 'jq'
    min_version = Version(1, 6, 0)
    max_version = Version(1, 7, 1)
    arch_alias = {
        'x86_64': 'amd64',
    }
    DOT_PATH = __dot_project__

    def __init__(self, binary_dir=None, version=None):
        self.bin_dir = binary_dir if binary_dir else self.DOT_PATH
        self.skip_install = str(version) == "0"
        self.version = self.get_max_version() if not version or self.skip_install else version
        self.default_path = f'{self.bin_dir}/{self.binary_name}/{self.version}/bin'
        self.bin_path =  self.default_path if self.bin_dir == self.DOT_PATH else os.path.join(self.bin_dir, 'bin')
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
            jq_path = self.get_binary()
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

    def get_binary(self):
        return binary_path(self.binary_name, self.bin_path, self.default_path)

    def install(self):

        if self.skip_install:
            logger.info('JQ 0 version used, skipping installation')
            return

        jq_bin = self.get_binary()
        # Skip installation if latest already installed
        if jq_bin == self.binary_full_path \
            and self.check_version() == self.version:
            logger.info(f'JQ {self.version} is already installed')
            return

        try:
            logger.info(f'Installing JQ {self.version} in {self.binary_full_path}')
            full_path = Path(self.binary_full_path)
            full_path.unlink(missing_ok=True)
            bin_path = Path(self.bin_path)
            bin_path.mkdir(parents=True, exist_ok=True)

            # Starting with version jq 1.7, the artifact release names have changed:
            # - jq-linux64 -> jq-linux-amd64
            # - jq-osx-amd64 -> jq-macos-amd64
            # - arm/darwin does not exist -> jq-macos-arm64
            base = f"https://github.com/jqlang/jq/releases/download/jq-{self.version}/"
            source_url = base + f'jq-{self.operating_system}-{self.architecture}'
            # Macos release constains macos in the name
            if self.operating_system == "darwin":
                source_url = base + f'jq-macos-{self.architecture}'
            # Handle version 1.6 releases
            if self.format_version(self.version).startswith('1.6'):
                if self.architecture == "arm64":
                    raise Exception("JQ 1.6 does not support arm64 architecture")

                if self.operating_system == "linux":
                    source_url = base + 'jq-linux64'

                if self.operating_system == "darwin":
                    source_url = base + 'jq-osx-amd64'

            binary_file = Path(Request.urlretrieve(source_url)[0])

            # Get sha256 checksum file
            checksum_url = base + f'sha256sum.txt'
            checksum_file = ""
            # unzip file and get signature froms from sig/v1.6/sha256sum.txt
            if self.format_version(self.version).startswith('1.6'):
                checksum_url = base + f'jq-1.6.zip'
                checksum_zip = Path(Request.urlretrieve(checksum_url, '/tmp/jq.zip')[0])
                checksum_file = Path('/tmp/jq-checksums')
                temp_dir = Path('/tmp/jq')
                shutil.unpack_archive(checksum_zip, temp_dir, 'zip')
                shutil.move(temp_dir / 'jq-1.6/sig/v1.6/sha256sum.txt', checksum_file)
                shutil.rmtree(temp_dir)
            else:
                checksum_file = Path(Request.urlretrieve(checksum_url)[0])

            # Verify checksum
            if not checksum_verify(binary_file, checksum_file, 'sha256'):
                binary_file.unlink(missing_ok=True)
                checksum_file.unlink(missing_ok=True)
                raise Exception(f'Failed to verify JQ {self.version} checksum')
            logger.info(f'Verified JQ {self.version} checksum')
            checksum_file.unlink(missing_ok=True)

            binary_file.rename(full_path)
            binary_file.unlink(missing_ok=True)
            full_path.chmod(0o770)
        except Exception as e:
            raise Exception(f'Failed to install JQ {self.version} - ({e})') from e
