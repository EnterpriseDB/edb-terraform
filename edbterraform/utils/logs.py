import logging
from logging.handlers import RotatingFileHandler
import os
from pathlib import Path
import sys
from datetime import datetime
from enum import Enum, EnumMeta
from edbterraform import __project_name__, __dot_project__
import itertools

logger = logging.getLogger(__project_name__)

class EnumDefaults(EnumMeta):
    def __call__(cls, value='', default=None, *args, **kwargs):
        '''
        Always passthrough the initial call to super.
        If default is defined, attempt a second call with default instead of raising the error.
        '''
        try:
            return super().__call__(value, *args, **kwargs)
        except:
            if default is not None:
                return super().__call__(default, *args, **kwargs)
            raise

class LogLevel(Enum, metaclass=EnumDefaults):
    NOTSET = logging.NOTSET
    DEBUG = logging.DEBUG
    INFO = logging.INFO
    WARN = logging.WARN
    WARNING = logging.WARNING
    ERROR = logging.ERROR
    FATAL = logging.FATAL
    CRITICAL = logging.CRITICAL

    @classmethod
    def _missing_(cls, value):
        if value == '':
            return cls.NOTSET

        if isinstance(value, str):
            if value.isdigit():
                return cls(int(value))

            # Find the first alpha string in the value
            not_isalpha = lambda x: not str.isalpha(x)
            value = "".join(itertools.dropwhile(not_isalpha, value))
            value = "".join(itertools.takewhile(str.isalpha, value))
            # All values should be upper case
            value = value.upper()
            if value in dir(cls):
                return cls[value]

    def __str__(self):
        return f"{self.name}"

    def __int__(self):
        return self.value

    @classmethod
    def available_options(cls):
        options = ""
        for level in cls:
            options += f"{level.name}: {level.value}\n"
        return options

def setup_logs(level=LogLevel.INFO, file_name=datetime.now().strftime('%Y-%m-%d'), directory=f'{__dot_project__}/logs', stdout=True):
    try:
        log_format = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        date_format = '%Y-%m-%dT%H:%M:%S%z'
        directory = Path(directory).resolve()
        file_name = directory / file_name
        log_level = LogLevel(level, logging.WARNING)

        if stdout:
            logging.basicConfig(level=log_level.value, stream=sys.stdout, datefmt=date_format, format=log_format)
        else:
            directory.mkdir(parents=True, exist_ok=True)
            log_handler = RotatingFileHandler(str(file_name), maxBytes=10*1024*1024, backupCount=10, mode='a')
            logging.basicConfig(level=log_level.value, datefmt=date_format, format=log_format, handlers=[log_handler])
    except Exception as e:
        logger.error(f"Trouble setting up logger - ({e})")
        sys.exit(1)
