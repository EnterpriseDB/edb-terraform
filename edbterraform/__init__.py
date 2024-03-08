__version__ = "1.7.4"
__project_name__ = 'edb-terraform'
from pathlib import Path
__dot_project__ = f'{Path.home()}/.{__project_name__}'

import sys
__python_version__ = '%s.%s.%s-%s.%s' % (
    sys.version_info.major,
    sys.version_info.minor,
    sys.version_info.micro,
    sys.version_info.releaselevel,
    sys.version_info.serial
)
# Check if we are in a python virtual environment
__virtual_env__ = sys.prefix != sys.base_prefix
