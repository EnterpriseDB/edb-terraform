import yaml
from pathlib import Path
import os
import sys
from jinja2 import (
    Environment,
    FileSystemLoader,
    TemplateError,
    meta as Jinja2Meta,
    nodes as Jinja2Nodes,
    StrictUndefined,
    UndefinedError,
)

MAX_PATH_LENGTH = os.pathconf('/', 'PC_PATH_MAX')
MAX_NAME_LENGTH = os.pathconf('/', 'PC_NAME_MAX')

def load_yaml_file(input: str, top_level_types: tuple = ()) -> dict:
    '''
    Load yaml from a file or a string.
    - Valid json accepted as well since it is valid yaml.
    - Allow restricting the top level type to a list of valid types.

    Args:
        input (str): a file path or a string
        top_level_types (tuple): a tuple of valid format types
    Returns:
        dict: the yaml data
    '''
    mod_inputs = input
    values = {}

    try:
        if len(str(mod_inputs)) <= MAX_PATH_LENGTH \
            and len(str(mod_inputs).split('/')[-1]) <= MAX_NAME_LENGTH \
            and Path(mod_inputs).exists():
                mod_inputs = Path(mod_inputs).read_text()

        values = yaml.safe_load(mod_inputs)

        # Allow restricting the top level type to a list of valid types
        if top_level_types and not isinstance(values, top_level_types):
            raise TypeError("ERROR: Invalid format type for the data: %s - %s - (%s)" % (top_level_types, input, type(input)))

        return values

    except Exception as e:
        raise yaml.YAMLError("ERROR: could not read as a file or as a string - %s - (%s)" % (input, repr(e))) from e

def render_template(template_file: Path, values={}) -> str:
    '''
    Render a jinja2 template with the given values and return its contents.

    Args:
        template_file (Path): the template file path.
        values (dict): data to be used in the template.

    Returns:
      str: Rendered contents of the template.
    '''
    try:
        # Jinja2 rendering
        file_loader = FileSystemLoader(template_file.parent)
        env = Environment(loader=file_loader, trim_blocks=True, keep_trailing_newline=True, undefined=StrictUndefined)
        template = env.get_template(template_file.name)
        # Render the template
        content = template.render(**values)
        return content

    except Exception as e:
        error_msg = "ERROR: could not render template %s - (%s)" % (template_file, repr(e))
        if isinstance(e, UndefinedError):
            error_msg += "\nTemplate variables: %s" % template_variables(template_file, values)

        raise TemplateError(error_msg) from e

def template_variables(template_file: Path, values: dict={}) -> dict:
    '''
    Get a jinja2 templates pre-set variables, undeclared variables and input variables.

    Args:
        template_file (Path): the template file path.
        values (dict): data to be used in the template.

    Returns:
      dict: Contains keys for 'set', 'undeclared' and 'inputs'.
    '''
    try:
        file_loader = FileSystemLoader(template_file.parent)
        env = Environment(loader=file_loader, trim_blocks=True)
        ast = env.parse(template_file.read_text())

        set_variables = dict()
        for node in ast.body:
            if not isinstance(node, (Jinja2Nodes.TemplateData, Jinja2Nodes.Output)):
                key = node.target.name
                value = node.node
                set_variables[key] = value

        undeclared_variables = [ key for key in Jinja2Meta.find_undeclared_variables(ast) if key not in set_variables ]

        return {
            "set": set_variables,
            "undeclared": undeclared_variables,
            "inputs": values,
        }
    except Exception as e:
        raise TemplateError("ERROR: could not parse template variables - %s - (%s)" % (template_file, repr(e))) from e
