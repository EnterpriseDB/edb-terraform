import yaml
import os
import sys

def load_yaml_file(file_path):

    if not os.path.exists(file_path):
        sys.exit("ERROR: file %s not found" % file_path)

    try:
        with open(file_path) as f:
            vars = yaml.load(f.read(), Loader=yaml.CLoader)
            return vars

    except Exception as e:
        sys.exit("ERROR: could not read file %s (%s)" % (file_path, e))
