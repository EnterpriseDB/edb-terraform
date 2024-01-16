import yaml
from pathlib import Path
import sys

def load_yaml_file(input: str):
    '''
    Load a yaml or json from a file or a string
    return a dict
    '''
    values = {}

    try:
        if Path(input).exists():
            with open(Path(input), 'r') as file:
                values = yaml.safe_load(file.read())
        else:
            values = yaml.safe_load(input)

        return values

    except Exception as e:
        sys.exit("ERROR: could not read as a file or as a string:%s (%s)" % (input, e))
