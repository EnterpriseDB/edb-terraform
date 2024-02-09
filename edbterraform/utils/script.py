import os
from pathlib import Path
import subprocess
from tempfile import mkstemp
import stat
from dataclasses import dataclass, field
from typing import Union
from enum import Enum, auto
from collections.abc import Sequence
import itertools
import re

from edbterraform.utils.logs import logger

class TaintHandle(Enum):
    '''
    Enum for handling tainted patch versions where releaselevel is part of the patch
    By default, replace the tainted patch's releaselevel with the explicit releaselevel
    '''
    REPLACE = auto()
    APPEND = auto()
    PREPEND = auto()
    KEEP = auto()

    @classmethod
    def _missing_(cls, value):
        if value is None or value == '':
            return cls.REPLACE

        if isinstance(value, str):
            value = value.upper()
            if value in dir(cls):
                return cls[value]

    def __str__(self):
        return f"{self.__class__.__name__}.{self.name}"


@dataclass(order=True)
class Version:

    # Semvar strings are major.minor.patch-releaselevel+build
    major: int = field(repr=True, init=False, default=0, compare=False)
    minor: int = field(repr=True, init=False, default=0, compare=False)
    patch: int = field(repr=True, init=False, default=0, compare=False)
    releaselevel: str = field(repr=True, init=False, default='', compare=False)
    build: str = field(repr=True, init=False, default=None, compare=False)
    sort_index: tuple = field(repr=False, init=False, compare=True) # Use the sort_index as the comparison key
    raw: Union[Sequence, str] = field(repr=False, init=True, default="0.0.0", compare=False)
    version_type: str = field(repr=False, init=True, default="semvar", compare=False)
    taint_handling: str = field(repr=False, init=True, default=TaintHandle.PREPEND.name, compare=False)
    tainted_major: str = field(repr=False, init=True, default=None, compare=False)
    tainted_minor: str = field(repr=False, init=True, default=None, compare=False)
    tainted_patch: str = field(repr=False, init=True, default=None, compare=False)
    untainted_releaselevel: str = field(repr=False, init=True, default=None, compare=False)
    original: Union[Sequence, str] = field(repr=False, init=False, default=None, compare=False)

    def __post_init__(self):
        if not isinstance(self.raw, (Sequence, str)):
            raise TypeError("Version must be a tuple or a string")

        self.original = self.raw
        if not isinstance(self.raw, str) and isinstance(self.raw, Sequence):
            temp = self.raw
            self.raw = ''
            self.raw += f"{temp[0] if temp[0:] and temp[0] else str(0)}"
            self.raw += f".{temp[1] if temp[1:] and temp[1] else str(0)}"
            self.raw += f".{temp[2] if temp[2:] and temp[2] else str(0)}"
            self.raw += f"-{temp[3]}" if temp[3:] and temp[3] else ''
            self.raw += f"+{temp[4]}" if temp[4:] and temp[4] else ''

        # Remove 'v' from start and split the string into major, minor, patch
        # Tools such as jq release versions as x.xrc3
        # Patch should only contain integers but will be handled later
        version_parts = self.raw.lstrip('v').split('.', 2)
        self.major, self.tainted_major = self.nonstandard_segment(version_parts[0] if version_parts[0:] and version_parts[0] is not None else 0)
        self.minor, self.tainted_minor = self.nonstandard_segment(version_parts[1] if version_parts[1:] and version_parts[1] is not None else 0)
        self.patch, self.tainted_patch = self.nonstandard_segment(version_parts[2] if version_parts[2:] and version_parts[2] is not None else 0)

        if self.version_type == "semvar":
            return self.__semvar_releaselevel(self.raw)

        raise NotImplementedError("Only semvar is supported")

    def __semvar_releaselevel(self, semvar_version):
        '''
        Extract the releaselevel and build metadata from the patch
        Depending on the taint_handling, the releaselevel will be replaced, appended, prepended or kept with the tainted versions
        '''
        # Get the buildmeta data from the first seen '+' symbol
        extract = semvar_version.split('+', 1)
        self.build = extract[1] if len(extract) == 2 else ""

        # Get the releaselevel
        # Some versions may contain a series of identiers such as 1.0.0.[0-1.0.0]+1 
        #   where the items in the brackets are the releaselevel 1.0.0-0-1.0.0+1
        versions = extract[0].split('-', 1)
        self.releaselevel = versions[1] if len(versions) == 2 else ""

        extract = versions[0].split('.')
        release = ".".join(extract[3:])
        self.releaselevel = release if release and not self.releaselevel else self.releaselevel if not release and self.releaselevel else release + "-" + self.releaselevel if release and self.releaselevel else ""

        if TaintHandle(self.taint_handling) == TaintHandle.KEEP:
            self.releaselevel = self.tainted_major if self.tainted_major else ""
            self.releaselevel += f".{self.tainted_minor}" if self.tainted_minor and self.releaselevel else self.tainted_minor if self.tainted_minor else ""
            self.releaselevel += f".{self.tainted_patch}" if self.tainted_patch and self.releaselevel else self.tainted_patch if self.tainted_patch else ""
        if TaintHandle(self.taint_handling) == TaintHandle.APPEND:
            self.releaselevel += self.tainted_major if self.tainted_major else ""
            self.releaselevel += f".{self.tainted_minor}" if self.tainted_minor and self.releaselevel else self.tainted_minor if self.tainted_minor else ""
            self.releaselevel += f".{self.tainted_patch}" if self.tainted_patch and self.releaselevel else self.tainted_patch if self.tainted_patch else ""
        elif TaintHandle(self.taint_handling) == TaintHandle.PREPEND:
            temp = self.releaselevel
            self.releaselevel = self.tainted_major if self.tainted_major else ""
            self.releaselevel += f".{self.tainted_minor}" if self.tainted_minor and self.releaselevel else self.tainted_minor if self.tainted_minor else ""
            self.releaselevel += f".{self.tainted_patch}" if self.tainted_patch and self.releaselevel else self.tainted_patch if self.tainted_patch else ""
            self.releaselevel += f".{temp}" if temp and self.releaselevel else temp if temp else ""
        else:
            # Assumes TaintHandle(self.taint_handling) == TaintHandle.REPLACE
            pass

        self.sort_index = self.__sort_keys()

    def nonstandard_segment(self, version):
        '''
        Given a non standard version with releaselevel, 1rc3-1.0.0+1,
        return a standard semvar version and releaselevel (1, 'rc3')
        '''
        # Extract the patch number
        patch_number = int("".join(itertools.takewhile(str.isdigit, str(version))))
        extract = str(version).lstrip(str(patch_number))
        patch_number = int(patch_number if patch_number else 0)

        # Extract the releaselevel if it is part of the patch
        releaselevel = "".join(itertools.takewhile(str.isalnum, extract))
        releaselevel = releaselevel if releaselevel else ''
        return (patch_number, releaselevel)

    def __sort_keys(self) -> tuple:
        '''
        Compare the version (major, minor, patch)
        '''
        return (
            self.major,
            self.minor,
            self.patch,
        )

    def to_tuple(self):
        return (self.major, self.minor, self.patch)

    def to_tuple_semvar(self):
        return self.to_tuple() + (
            self.releaselevel,
        )

    def to_tuple_full(self):
        return self.to_tuple() + (
            self.releaselevel,
            self.build,
        )

    def to_string(self, include_zero_patch=True, tainted=False):
        '''
        Return a string representation of the version.
        If tainted is True, the version numbers will be replaced with the tainted versions
        If include_zero_patch is False, the patch number will be omitted if it is 0 and the patch was not tainted
        '''
        versions = [str(self.major), str(self.minor), str(self.patch)]
        if tainted:
            versions = [versions[0]+self.tainted_major, versions[1]+self.tainted_minor, versions[2]+self.tainted_patch]
        if not include_zero_patch \
            and self.patch == 0 \
            and not self.tainted_patch:
            versions.pop()

        return ".".join(versions)

    def to_string_full(self, include_zero_patch=True, tainted=False):
        version = self.to_string(include_zero_patch, tainted)
        # Use the untainted releaselevel if using the tainted version to avoid duplicate releaselevel values
        if self.untainted_releaselevel and tainted:
            version += f"-{self.untainted_releaselevel}"
        elif self.releaselevel and not tainted:
            version += f"-{self.releaselevel}"

        if self.build:
            version += f"+{self.build}"

        return version

def execute_shell(args, environment=os.environ, cwd=None):
    fmt_args = ' '.join([str(x) for x in args])
    logger.info("Executing command: %s", fmt_args)
    logger.debug("environment=%s", environment)
    try:
        process = subprocess.check_output(
            fmt_args,
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
    fmt_args = ' '.join([str(x) for x in args])
    logger.info("Executing command: %s", fmt_args)
    logger.debug("environment=%s", environment)
    process = subprocess.Popen(
        fmt_args,
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

def binary_path(name, bin_path=None, default_path=None, env_path="PATH",):
    """Returns the first seen binary

    Order:
    1. bin_path + name if it exists
    2. PATH + name if it exists
    3. default_path + name if it exists
    3. Empty string

    :param name: name of the binary
    :param bin_path: path to look for the binary
    :param env_path: environments PATH variable
    :param default_path: default path to look for the binary
    """
    if not name:
        return ''

    if bin_path:
        binary_path = Path(bin_path) / name
        if binary_path.exists() and os.access(binary_path, os.X_OK):
            return binary_path

    if env_path:
        paths = os.getenv(env_path,'').split(os.pathsep)
        for path in paths:
            binary_path = Path(path) / name
            if binary_path.exists() and os.access(binary_path, os.X_OK):
                return binary_path

    if default_path:
        binary_path = Path(default_path) / name
        if binary_path.exists() and os.access(binary_path, os.X_OK):
            return binary_path

    return ''
