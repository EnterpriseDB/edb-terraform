import logging
from logging.handlers import RotatingFileHandler
import os
import sys
from pathlib import Path
from datetime import datetime
from edbterraform import __project_name__

logger = logging.getLogger(__project_name__)

def setup_logs(level='INFO', file_name=datetime.now().strftime('%Y-%m-%d'), directory=f'{Path.home()}/.{__project_name__}/logs', stdout=True):
    if not os.path.exists(directory):
        os.makedirs(directory)

    log_format = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    date_format = '%Y-%m-%dT%H:%M:%S%z'

    log_level = getattr(logging, level, logging.WARNING)

    if stdout:
        logging.basicConfig(level=log_level, stream=sys.stdout, datefmt=date_format, format=log_format)
    else:
        log_handler = RotatingFileHandler(file_name, maxBytes=10*1024*1024, backupCount=10, mode='a')
        logging.basicConfig(level=log_level, datefmt=date_format, format=log_format, handlers=[log_handler])
