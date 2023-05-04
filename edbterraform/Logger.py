import logging
from logging.handlers import RotatingFileHandler
import os
import sys
from pathlib import Path
from datetime import datetime
from edbterraform import __project_name__

DEFAULT_DIR = f'{Path.home()}/.{__project_name__}/logs'

if not os.path.exists(DEFAULT_DIR):
    os.makedirs(DEFAULT_DIR)

timestamp = datetime.now().strftime('%Y-%m-%d')
log_format = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
date_format = '%Y-%m-%dT%H:%M:%S%z'

log_file = os.getenv("LOG_FILE", os.path.join(DEFAULT_DIR, f'{timestamp}.log'))
log_stdout = os.getenv('LOG_STDOUT', None)
level = os.getenv("LOG_LEVEL",'WARNING').upper()
log_level = getattr(logging, level, logging.WARNING)


if log_stdout:
    logging.basicConfig(level=log_level, stream=sys.stdout, datefmt=date_format, format=log_format)
else:
    log_handler = RotatingFileHandler(log_file, maxBytes=10*1024*1024, backupCount=10, mode='a')
    logging.basicConfig(level=log_level, datefmt=date_format, format=log_format, handlers=[log_handler])

logger = logging.getLogger(__project_name__)
