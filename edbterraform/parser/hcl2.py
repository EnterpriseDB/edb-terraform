import hcl2
from pathlib import Path
from typing import Union
import logging
import re
import json
import ast
import pygohcl

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

# TODO: Parse type information or use a different library such as:
# - https://github.com/hashicorp/terraform-config-inspect
# - https://github.com/Scalr/pygohcl
# - https://github.com/cloud-custodian/tfparse
# - Manual/Lark parsing
def load_hcl2(project_path: Union[str, Path] = None, load_tf = True, load_tf_vars = False, load_json = False, filename_base="variables"):
    try:
        results = {}
        project_path = (Path(project_path)).resolve()
        files = (
            project_path.glob(f'*{filename_base}*.tf') if load_tf else []
            + project_path.glob(f'*{filename_base}*.tf.json') if load_tf and load_json else []
            + project_path.glob(f'*{filename_base}*.tfvars') if load_tf_vars else []
            + project_path.glob(f'*{filename_base}*.tfvars.json') if load_tf_vars and load_json else []
        )
        for file in files:
            data = hcl2.loads(file.read_text())
            results[file] = data
        return results

    except Exception as e:
        raise Exception("ERROR: could not load hcl2 data - %s - (%s)" % (project_path, repr(e))) from e

def load_specification(project_path: Union[str, Path] = None, filename_base="spec",):
    '''
    Extract specification from terraform data
    '''
    try:
        spec_vars = load_hcl2(project_path, load_tf = True, filename_base=filename_base)
        variables_only = load_vars(spec_vars)
        print(json.dumps(variables_only, indent=2))
        return variables_only
    except Exception as e:
        raise e

def load_vars(spec_object):
    '''
    Extract variables from terraform data
    '''
    KEYNAME = "variable"
    variables = {}
    try:
        for _, data in spec_object.items():
            for variable in data.get(KEYNAME, []):
                for top_key, type_values in variable.items():
                    if top_key in variables:
                        logging.warning(f"Duplicate variable ({top_key}) exists with value ({variables[top_key]}) and overriding")
                    inner_dict = {}
                    for inner_key, inner_value in type_values.items():
                        # merge the top dict values to override the top "type" key
                        if inner_key == 'type':
                            inner_value = extract_type(inner_value)
                            if type(inner_value) == dict:
                                inner_dict = {**inner_dict, **inner_value}
                            else:
                                inner_dict[inner_key] = inner_value
                        else:
                            inner_dict[inner_key] = inner_value
                    # override top-level "required"
                    # top-level variables do not accept optional
                    # instead 'nullable' and 'default' is used to determine if a variable is 'required'
                    # - 'nullable = true' or omitted allows for the value to be set to null
                    # - 'default = <value>' sets the value whenever it is not provided
                    inner_dict["required"] = True if not "default" in inner_dict else False
                    variables[top_key] = inner_dict
        return variables
    except Exception as e:
        raise e

def extract_type(value):
    '''
    Extract type from terraform's type data.
    The type is not parsed and requires further processing.
    '''
    # check for recursive types
    if type(value) == str and value in TERRAFORM_PYTHON_TYPES:
        return str(TERRAFORM_PYTHON_TYPES[value])

    if value.startswith('${') and value.endswith('}'):
        value = extract_type(value[2:-1])
    elif value.startswith('\\') and value.endswith('\\'):
        value = extract_type(value[1:-1])
    elif value.startswith('map(') and value.endswith(')'):
        value = {
            "type": "map",
            "required": True,
            "properties": extract_type(value[4:-1]),
        }
    elif value.startswith('object(') and value.endswith(')'):
        value = {
            "type": "object",
            "required": True,
            "properties": extract_type(value[7:-1]),
        }
    elif value.startswith('list(') and value.endswith(')'):
        value = {
            "type": "list",
            "required": True,
            "properties": extract_type(value[5:-1]),
        }
    elif value.startswith('optional(') and value.endswith(')'):
        type_value, default_value = split_optional_values(value)
        value = extract_type(type_value)
        if type(value) != dict:
            value = {"type": value}
        value["required"] = False
        value["default"] = default_value
    elif value.startswith('{') and value.endswith('}'):
        value = ast.literal_eval(value)
        for k,v in value.items():
            value[k] = extract_type(v)

    return value

def split_optional_values(s):
    '''
    Given a string from optional, split at the first comma that is not inside a nested structure.
    ex: "optional(string, "example")" -> ["string", "example"]
    ex: "optional(map(string), {})" -> ["map(string)", "{}"]
    ex: "optional(map(string)) -> ["map(string)", None]
    '''
    if s.startswith('optional(') and s.endswith(')'):
        s = s[9:-1]
    count = 0
    split_index = -1
    for i, char in enumerate(s):
        if char == '{':
            count += 1
        elif char == '}':
            count -= 1
        elif char == ',' and count == 0:
            split_index = i
            break
    type_value = s
    default_value = None
    if split_index != -1:
        type_value = s[:split_index].strip()
        default_value = s[split_index+1:].strip()
    return [type_value, default_value]

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
