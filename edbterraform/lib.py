# coding: utf-8

import json
from pathlib import Path, PurePath
import os
import sys
import shutil
import subprocess
import logging
from jinja2 import Environment, FileSystemLoader

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.backends import default_backend
try:
    from edbterraform.utils.dict import change_keys
    from edbterraform.utils.files import load_yaml_file
except:
    from utils.dict import change_keys
    from utils.files import load_yaml_file

def tpl(template_name, dest, csp, vars={}):
    # Renders and saves a jinja2 template based on a given template name and
    # variables.

    try:
        # Templates are located in __file__/data/templates/<cloud-service-provider>
        current_dir = Path(__file__).parent.resolve()
        templates_dir = PurePath.joinpath(
            current_dir, 'data', 'templates', csp
        )

        # Jinja2 rendering
        file_loader = FileSystemLoader(str(templates_dir))
        env = Environment(loader=file_loader, trim_blocks=True)
        template = env.get_template(template_name)

        # Render and save
        content = template.render(**vars)
        with open(dest, 'w') as f:
            f.write(content)

    except Exception as e:
        sys.exit("ERROR: could not render template %s (%s)"
                 % (template_name, e))

def create_project_dir(dir, csp):
    # Creates a new terraform project (directory) and copy terraform modules
    # into this directory.

    if os.path.exists(dir):
        sys.exit("ERROR: directory %s already exists" % dir)

    script_dir = Path(__file__).parent.resolve()
    try:
        logging.info(f'Creating directory: {dir}')
        shutil.copytree(script_dir / 'data' / 'terraform' / csp, dir)
    except Exception as e:
        sys.exit("ERROR: cannot create project directory %s (%s)" % (dir, e))

def destroy_project_dir(dir):
    if not os.path.exists(dir):
        return

    try:
        logging.info(f'Destroying directory: {dir}')
        shutil.rmtree(dir)
    except Exception as e:
        raise("Error: unable to delete project directory %s (%s)" % (dir, e))

def save_terraform_vars(dir, filename, vars):
    # Saves terraform variables as a JSON file.

    dest = dir / filename
    try:
        with open(dest, 'w') as f:
            f.write(json.dumps(vars, indent=2, sort_keys=True))
    except Exception as e:
        sys.exit("ERROR: could not write %s (%s)" % (dest, e))


def regions_to_peers(regions):
    # Build a list of peer regions, based on a given list of regions.
    # For example, taking the following region list: [A, B, C, D]
    # List of peers will be: [(A, B), (A, C), (A, D), (B, C), (B, D), (C, D)]

    # At this point, regions is a dict coming directly from the infrastructure
    # file, we need to convert if to a list of regions.
    region_list = list(regions.keys())
    region_list_cpy = region_list.copy()
    peer_list = []
    i = 0

    for r in region_list:
        for p in range(i+1, len(region_list_cpy)):
            peer_list.append((r, region_list_cpy[p]))
        i += 1

    return peer_list


def object_regions(object_type, vars):
    # Returns the region list used by an object type. Object types are:
    # machines or databased

    regions = []

    if object_type not in vars:
        return regions

    for _, value in vars[object_type].items():
        region = value.get('region')

        if not region:
            continue

        if region not in regions:
            regions.append(region)

    return regions

def build_vars(csp: str, infra_vars: Path, server_output_name: str):

    # Based on the infra variables, returns a tuple composed of (terraform
    # variables as a dist, template variables as a dict)

    # Get a spec compatable object
    infra_vars = spec_compatability(infra_vars, csp)

    # Variables used in the template files
    # Build jinja template variable
    template_vars = dict(
        output_name = server_output_name,
        has_region_peering=(len(infra_vars['regions'].keys()) > 1),
        has_regions=('regions' in infra_vars),
        has_machines=('machines' in infra_vars),
        has_databases=('databases' in infra_vars),
        has_kubernetes=('kubernetes' in infra_vars),        
        regions=infra_vars['regions'].copy(),
        peers=regions_to_peers(infra_vars['regions']),
        machine_regions=object_regions('machines', infra_vars),
        database_regions=object_regions('databases', infra_vars),
        kubernetes_regions=object_regions('kubernetes', infra_vars),

        # AWS Specific
        has_aurora=('aurora' in infra_vars),
        aurora_regions=object_regions('aurora', infra_vars),

        # GCloud Specific
        has_alloy=('alloy' in infra_vars),
        alloy_regions=object_regions('alloy', infra_vars),
    )

    # Starting with making a copy of infra_vars as our terraform_vars dict
    # Since our terraform modules implement a specification module,
    # it needs the the cloud service provider values from the file as a terraform `spec` variable
    terraform_vars = dict(
        spec = infra_vars.copy(),
    )
    
    return (terraform_vars, template_vars)

def generate_terraform(infra_file: Path, project_path: Path, csp: str, run_validation: bool) -> dict:
    """
    Generates the terraform files from jinja templates and terraform modules and
    saves the files into a project_directory for use with 'terraform' commands

    Returns a dictionary with the following keys:
    - terraform_output: usable with terraform outputs command after terraform apply 
    - ssh_user
    - ssh_filename
    """
    SERVERS_OUTPUT_NAME = 'servers'
    TERRAFORM_STATE_FILE = project_path / 'terraform.tfstate'
    PROJECT_PATH_PERMISSIONS = 0o750
    TERRAFORM_STATE_PERMISSIONS = 0o600
    OUTPUT = {
        'terraform_output': '',
        'ssh_user': '',
        'ssh_filename': '',
    }

    # Load infrastructure variables from the YAML file that was passed
    infra_vars = load_yaml_file(infra_file)

    # Duplicate terraform code into target project directory
    create_project_dir(project_path, csp)

    # Transform variables extracted from the infrastructure file into
    # terraform and templates variables.
    (terraform_vars, template_vars) = \
        build_vars(csp, infra_vars, SERVERS_OUTPUT_NAME)

    # Save terraform vars file
    save_terraform_vars(
        project_path, 'terraform.tfvars.json', terraform_vars
    )

    # Generate the main.tf and providers.tf files.
    tpl(
        'main.tf.j2',
        project_path / 'main.tf',
        csp,
        template_vars
    )
    tpl(
        'providers.tf.j2',
        project_path / 'providers.tf',
        csp,
        template_vars
    )

    # Create statefile and change file/folder permissions since
    # it is not-encrypted by default and may contain secrets
    open(project_path / TERRAFORM_STATE_FILE, 'w').close()
    os.chmod(project_path, PROJECT_PATH_PERMISSIONS)
    os.chmod(TERRAFORM_STATE_FILE, TERRAFORM_STATE_PERMISSIONS)

    # terraform_vars holds the spec object for use in terraform
    OUTPUT['terraform_output'] = SERVERS_OUTPUT_NAME
    if 'ssh_user' in terraform_vars['spec']:
        OUTPUT['ssh_user'] = terraform_vars['spec']['ssh_user']
    if 'ssh_key' in terraform_vars['spec'] and 'output_name' in terraform_vars['spec']['ssh_key']:
        OUTPUT['ssh_filename'] = terraform_vars['spec']['ssh_key']['output_name']

    run_terraform(project_path, run_validation)

    return OUTPUT

def run_terraform(cwd, validate):
    if validate:
        try:
            command = 'command -v terraform'
            logging.info(f'Executing command: {command}')
            subprocess.check_output(
                command,
                shell=True,
                cwd=cwd,
                stderr=subprocess.STDOUT,
                text=True
            )
        except subprocess.CalledProcessError as e:
            logging.warning(f'''
            Validation skipped, terraform not found.
            Remove --validate option or install terraform >= 1.3.6
            and rerun edb-terraform
            Install and manually run:
            1. `terraform init`
            2. `terraform plan`
            3. `terraform apply -target=null_resource.validation`
            ''')
            destroy_project_dir(cwd)
            sys.exit(e.returncode)
    
        try:
            command = 'terraform init'
            logging.info(f'Executing command: {command}')
            subprocess.check_output(
                command,
                shell=True,
                cwd=cwd,
                stderr=subprocess.STDOUT,
                text=True
            )
        except subprocess.CalledProcessError as e:
            logging.error(f'Error: ({e.output})')
            destroy_project_dir(cwd)
            sys.exit(e.returncode)
    
        try:
            command = 'terraform plan -input=false'    
            logging.info(f'Executing command: {command}')
            subprocess.check_output(
                command,
                shell=True,
                cwd=cwd,
                stderr=subprocess.STDOUT,
                text=True
            )

            command = 'terraform apply -input=false -target=null_resource.validation -auto-approve'
            logging.info(f'Executing command: {command}')
            subprocess.check_output(
                command,
                shell=True,
                cwd=cwd,
                stderr=subprocess.STDOUT,
                text=True
            )
        except subprocess.CalledProcessError as e:
            logging.error(f'Error: unable to validate terraform files.\n({e.output})')
            destroy_project_dir(cwd)
            sys.exit(e.returncode)

"""
Support backwards compatability to older specs 
since each collection of modules should implement a specification module
with the shape of the data it expects
"""
def spec_compatability(infrastructure_variables, cloud_service_provider):

    SSH_OUT_FILENAME = 'ssh-id_rsa'
    spec_variables = None

    try:
        spec_variables = infrastructure_variables[cloud_service_provider].copy()
    except:
        raise KeyError("ERROR: key '%s' not present in the infrastructure file." % cloud_service_provider)
    
    # Users were able to use 'cluster_name' at the same level as cloud_service_provider before
    if 'tags' not in spec_variables:
        spec_variables['tags'] = dict()
    if 'cluster_name' not in spec_variables['tags'] and \
        'cluster_name' in infrastructure_variables:
        spec_variables['tags']['cluster_name'] = infrastructure_variables['cluster_name']

    # if not provided,
    # assign default output name for private/public ssh key filename
    if 'ssh_user' in spec_variables and \
        'ssh_key' not in spec_variables:
        spec_variables['ssh_key'] = dict()
    if 'ssh_key' in spec_variables and 'output_name' in spec_variables['ssh_key']:
        spec_variables['ssh_key']['output_name'] = SSH_OUT_FILENAME


    replace_pairs = {
        # Modules used to expect azs and az
        "azs": "zones",
        "az": "zone",
    }
    spec_variables = change_keys(spec_variables, replace_pairs)

    return spec_variables
