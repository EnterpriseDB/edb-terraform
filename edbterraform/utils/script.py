import os
from pathlib import Path
import subprocess
from tempfile import mkstemp
import stat

from edbterraform.utils.logs import logger

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
        paths = os.getenv("PATH",'').split(os.pathsep)
        for path in paths:
            binary_path = Path(path) / name
            if binary_path.exists() and os.access(binary_path, os.X_OK):
                return binary_path

    if default_path:
        binary_path = Path(default_path) / name
        if binary_path.exists() and os.access(binary_path, os.X_OK):
            return binary_path

    return ''
