import hcl2
from pathlib import Path
from typing import Union
import logging
import re

PREFIX_CHARS="${"
SUFFIX_CHARS="}"
TERRAFORM_PYTHON_TYPES = {
    "string": str,
    "number": float,
    "bool": bool,
    "list(string)": list[str],
    "list(number)": list[float],
    "map(string)": dict[str, str],
}

# TODO: Fix breaking changes or use a different library such as https://github.com/hashicorp/terraform-config-inspect
def load_hcl2(project_path: Union[str, Path] = None, load_tf = True, load_tf_vars = False, load_json = False, file_name="variables.tf"):
    try:
        base_filename = "var"
        results = {}
        project_path = (Path(project_path)).resolve()
        files = (
            project_path.glob(f'*{base_filename}*.tf') if load_tf else []
            + project_path.glob(f'*{base_filename}*.tf.json') if load_tf and load_json else []
            + project_path.glob(f'*{base_filename}*.tfvars') if load_tf_vars else []
            + project_path.glob(f'*{base_filename}*.tfvars.json') if load_tf_vars and load_json else []
        )
        for file in files:
            data = hcl2.loads(file.read_text())
            results[file] = data
        return results

    except Exception as e:
        raise Exception("ERROR: could not load hcl2 data - %s - (%s)" % (project_path, repr(e))) from e

def load_variables(project_path: Union[str, Path] = None,):
    '''
    Extract variables from terraform data
    '''
    KEYNAME = "variable"
    variables = {}
    try:
        data = load_hcl2(project_path, load_tf = True)
        for _, data in data.items():
            for variable in data.get(KEYNAME, []):
                for key, value in variable.items():
                    if key in variables:
                        logging.warning(f"Duplicate variable ({key}) exists with value ({variables[key]}) and overriding")
                    variables[key] = value
        return variables

    except Exception as e:
        raise

def root_variable_help_message(variables):
    '''
    Format variables for use as a help message
    '''
    message = "Variables:\n"
    for key, value in variables.items():
        message += f"  {key}:\n"
        message += f"    type: {value.get('type').lstrip('${').rstrip('}')}\n" if value.get('type', False) else ""
        message += f"    description: {value.get('description')}\n" if value.get('description', False) else ""
        message += f"    default: {value.get('default')}\n" if value.get('default', False) else ""
        message += f"    nullable: {value.get('nullable')}\n" if value.get('nullable', False) else ""
        message += f"    environment variable: TF_VAR_{key}=<value>\n"
        message += f"    command line argument: -var \"{key}=<value>\" \n"
    return message

def module_variable_help_message(variables):
    '''
    Format variables for use as a help message
    '''
    message = "Variables:\n"
    for key, value in variables.items():
        message += f"  {key}:\n"
        message += f"    type: {value.get('type').lstrip('${').rstrip('}')}\n" if value.get('type', False) else ""
        message += f"    description: {value.get('description')}\n" if value.get('description', False) else ""
        message += f"    default: {value.get('default')}\n" if value.get('default', False) else ""
        message += f"    nullable: {value.get('nullable')}\n" if value.get('nullable', False) else ""
    return message
