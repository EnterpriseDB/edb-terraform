import logging
from logging.handlers import RotatingFileHandler
import os
import sys
from datetime import datetime
from edbterraform import __project_name__, __dot_project__

logger = logging.getLogger(__project_name__)

def setup_logs(level='INFO', file_name=datetime.now().strftime('%Y-%m-%d'), directory=f'{__dot_project__}/logs', stdout=True):
    try:
        log_format = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        date_format = '%Y-%m-%dT%H:%M:%S%z'

        log_level = getattr(logging, level, logging.WARNING)

        if stdout:
            logging.basicConfig(level=log_level, stream=sys.stdout, datefmt=date_format, format=log_format)
        else:
            if not os.path.exists(directory):
                os.makedirs(directory)
            log_handler = RotatingFileHandler(file_name, maxBytes=10*1024*1024, backupCount=10, mode='a')
            logging.basicConfig(level=log_level, datefmt=date_format, format=log_format, handlers=[log_handler])
    except Exception as e:
        logger.error("Trouble setting up logger")
        sys.exit(1)
