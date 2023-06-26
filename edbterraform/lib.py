# coding: utf-8

import json
import yaml
from pathlib import Path, PurePath
import os
import sys
import shutil
import subprocess
from jinja2 import Environment, FileSystemLoader
import textwrap
from typing import List

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.backends import default_backend

from edbterraform import __version__
from edbterraform.utils.dict import change_keys
from edbterraform.utils.files import load_yaml_file
from edbterraform.utils.logs import logger
from edbterraform.CLI import TerraformCLI
from edbterraform import __dot_project__

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
        logger.error("ERROR: could not render template %s (%s)" % (template_name, e))
        sys.exit(1)

def save_default_templates(templates_directory):
    '''
    Save any predefined templates into the 'directory/templates' for consistent referencing
    If the filename already exists, it should be skipped to avoid overriding user customizations.
    '''
    # Templates are located in parent_directory/data/templates/user
    script_dir = Path(__file__).parent.resolve()
    predefined_templates = script_dir / 'data' / 'templates' / 'user'
    templates_directory = Path(templates_directory)
    logger.info(f'Copy templates from {predefined_templates} into {templates_directory}')
    try:
        if not templates_directory.exists():
            logger.info(f'Creating predefined template directory: {templates_directory}')
            templates_directory.mkdir(parents=True, exist_ok=True)

        for template in predefined_templates.iterdir():
            if not template.is_file():
                logger.warning(f'Skipping {template} as it is not a file')
                continue

            if not (templates_directory / template.name).exists():
                shutil.copy2(str(template), str(templates_directory))
            else:
                logger.info(f'''
                Skipping: {template} already exists in {templates_directory}.
                To copy the latest pre-defined templates, erase any conflicting template file names.
                ''')
    except Exception as e:
        logger.error("ERROR: cannot create template directory %s (%s)" % (templates_directory, e))
        sys.exit(1)

def create_project_dir(project_directory, cloud_service_provider, infrastructure_file):
    '''
    Create new terraform project directory and copy needed files
    - cloud service provider modules
    - infrastructure.yml user file
      - edb-terraform.version key added
    '''
    if os.path.exists(project_directory):
        sys.exit("ERROR: directory %s already exists" % project_directory)

    script_dir = Path(__file__).parent.resolve()
    try:
        terraform_modules_directory = script_dir / 'data' / 'terraform' / cloud_service_provider
        infrastructure_final_file = project_directory / 'infrastructure.yml.bak'

        logger.info(f'Copying terraform modules {terraform_modules_directory} into {project_directory}')
        shutil.copytree(terraform_modules_directory, project_directory)
        
        logger.info(f'Copying infrastructure file {infrastructure_file} into {infrastructure_final_file}')
        shutil.copyfile(infrastructure_file, infrastructure_final_file)

        logger.info(f'Adding version to {infrastructure_final_file.name} under keys edb-terraform.version')
        with open(infrastructure_final_file, 'a') as f:
            f.write(yaml.dump({'edb-terraform': {'version': __version__}}))

    except Exception as e:
        logger.error("ERROR: cannot create project directory %s (%s)" % (project_directory, e))
        sys.exit(1)

def destroy_project_dir(dir):
    if not os.path.exists(dir):
        return

    try:
        logger.info(f'Destroying directory: {dir}')
        shutil.rmtree(dir)
    except Exception as e:
        raise("Error: unable to delete project directory %s (%s)" % (dir, e))

def save_terraform_vars(dir, filename, vars):
    # Saves terraform variables as a JSON file.

    dest = dir / filename
    try:
        with open(dest, 'w') as f:
            content = json.dumps(vars, indent=2, sort_keys=True)
            f.write(content)
    except Exception as e:
        logger.error("ERROR: could not write %s (%s)" % (dest, e))
        sys.exit(1)

def save_user_templates(project_path: Path, templates: List[str]):
    '''
    Save any user templates under project/templates
    For reuse during terraform execution and portability of directory
    '''
    logger.info(f'Saving user templates: {templates}')
    directory = "templates"
    basepath = project_path / directory

    try:
        if not basepath.exists():
            logger.info(f'Creating template directory: {basepath}')
            basepath.mkdir(parents=True, exist_ok=True)

        for template in templates:
            template = Path(template)

            if not template.exists():
                raise Exception("templates %s does not exist" % template)

            if template.is_dir():
                for file in template.iterdir():
                    logger.info(f'Copying {file} into {basepath}')
                    shutil.copy2(str(file), str(basepath))

            if template.is_file():
                logger.info(f'Copying {template} into {basepath}')
                shutil.copy2(str(template), str(basepath))

    except Exception as e:
        logger.error("Cannot create template (%s)" % (e))
        logger.error("Current working directory: %s" % (Path.cwd()))
        logger.error("List of templates: %s" % (templates))
        sys.exit(1)

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
        has_region_peering=(infra_vars.get('regions') and len(infra_vars['regions'].keys()) > 1),
        has_regions=('regions' in infra_vars),
        has_machines=('machines' in infra_vars),
        has_databases=('databases' in infra_vars),
        has_biganimal=('biganimal' in infra_vars),
        has_kubernetes=('kubernetes' in infra_vars),        
        regions=infra_vars.get('regions',{}).copy(),
        peers=regions_to_peers(infra_vars.get('regions',{})),
        machine_regions=object_regions('machines', infra_vars),
        database_regions=object_regions('databases', infra_vars),
        biganimal_regions=object_regions('biganimal', infra_vars),
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

def generate_terraform(infra_file: Path, project_path: Path, csp: str, run_validation: bool, bin_path: Path, user_templates: List[Path]) -> dict:
    """
    Generates the terraform files from jinja templates and terraform modules and
    saves the files into a project_directory for use with 'terraform' commands

    Returns a dictionary with the following keys:
    - terraform_output: usable with terraform outputs command after terraform apply 
    - ssh_filename
    """
    SERVERS_OUTPUT_NAME = 'servers'
    TERRAFORM_STATE_FILE = project_path / 'terraform.tfstate'
    PROJECT_PATH_PERMISSIONS = 0o750
    TERRAFORM_STATE_PERMISSIONS = 0o600
    OUTPUT = {
        'terraform_output': '',
        'ssh_filename': '',
    }

    # Load infrastructure variables from the YAML file that was passed
    infra_vars = load_yaml_file(infra_file)

    # Save default templates into dot directory
    save_default_templates(f'{__dot_project__}/templates')

    # Duplicate terraform code into target project directory
    create_project_dir(project_path, csp, infra_file)

    # Allow for user supplied templates
    # Terraform does not allow us to copy a template and then reference it within the same run when using templatefile()
    # To get past this, we will need to copy over all the user passed templates into the project directory
    infra_file_templates = infra_vars.get(csp, {}).get('templates', [])
    if not isinstance(infra_file_templates, list):
        raise TypeError("Template variables should pass in a list of strings that represent a path or rely on the CLI passthrough")
    # Remove templates from final terraform variables since save_user_templates will save them into project_name/templates/
    if infra_file_templates:
        del infra_vars[csp]['templates']
    user_templates.extend(infra_file_templates)
    save_user_templates(project_path, user_templates)

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
    open(TERRAFORM_STATE_FILE, 'w').close()
    os.chmod(project_path, PROJECT_PATH_PERMISSIONS)
    os.chmod(TERRAFORM_STATE_FILE, TERRAFORM_STATE_PERMISSIONS)

    # terraform_vars holds the spec object for use in terraform
    OUTPUT['terraform_output'] = SERVERS_OUTPUT_NAME
    if 'ssh_key' in terraform_vars['spec'] and 'output_name' in terraform_vars['spec']['ssh_key']:
        OUTPUT['ssh_filename'] = terraform_vars['spec']['ssh_key']['output_name']

    run_terraform(project_path, run_validation, bin_path)

    logger.info(textwrap.dedent('''
    Success!
    You can use now use terraform and see info about your boxes after creation:
    * cd {project_path}
    * terraform init
    * terraform apply -auto-approve
    * terraform output -json {output_key}
    * ssh <ssh_user>@<ip-address> -i {ssh_file}
    ''').format(
        project_path = project_path,
        output_key = OUTPUT['terraform_output'],
        ssh_file = OUTPUT['ssh_filename'],
    ))

    return OUTPUT

def run_terraform(cwd, validate, bin_path):
    if validate:
        try:
            terraform = TerraformCLI(bin_path)
            terraform.init_command(cwd)
            terraform.plan_command(cwd)
            terraform.apply_target_command(cwd)
        except subprocess.CalledProcessError as e:
            logger.warning(textwrap.dedent('''
            Validation skipped, check {bin_path}.
            Remove --validate option or install terraform >= {min_version}
            and rerun edb-terraform
            Install and manually run:
            1. `terraform init`
            2. `terraform plan`
            3. `terraform apply -target=null_resource.validation`
            ''').format(
                bin_path=bin_path,
                min_version=terraform.min_version,
            ))
            logger.error(f'Error: ({e.output})')
            destroy_project_dir(cwd)
            sys.exit(e.returncode)

"""
Support backwards compatability to older specs 
since each collection of modules should implement a specification module
with the shape of the data it expects
Anything defined here is depreciated and might be removed in future releases
"""
def spec_compatability(infrastructure_variables, cloud_service_provider):

    SSH_OUT_FILENAME = 'ssh-id_rsa'
    spec_variables = None

    try:
        spec_variables = infrastructure_variables[cloud_service_provider].copy()
    except:
        raise KeyError("ERROR: key '%s' not present in the infrastructure file." % cloud_service_provider)
    
    replace_pairs = {
        # Modules used to expect azs and az
        "azs": "zones",
        "az": "zone",
    }
    spec_variables = change_keys(spec_variables, replace_pairs)

    # Users were able to use 'cluster_name' at the same level as cloud_service_provider before
    if 'tags' not in spec_variables:
        spec_variables['tags'] = dict()
    if 'cluster_name' not in spec_variables['tags'] and \
        'cluster_name' in infrastructure_variables:
        spec_variables['tags']['cluster_name'] = infrastructure_variables['cluster_name']

    # if not provided,
    # assign default output name for private/public ssh key filename
    if 'ssh_key' not in spec_variables:
        spec_variables['ssh_key'] = dict()
    if 'ssh_key' in spec_variables and 'output_name' not in spec_variables['ssh_key']:
        spec_variables['ssh_key']['output_name'] = SSH_OUT_FILENAME

    # use 'image_name' to assign an os per instance,
    # which references an operating system from 'images' and includes 'ssh_user' 
    os_default = 'depreciated_default'
    if 'operating_system' in spec_variables:
        if 'images' not in spec_variables:
            spec_variables['images'] = {}
        spec_variables['images'][os_default] = spec_variables['operating_system']
        # 'ssh_user' can vary by image or use case and has been depreciated at the top level
        if 'ssh_user' in spec_variables:
            spec_variables['images'][os_default]['ssh_user'] = spec_variables['ssh_user']

        # update machines with depreciated default, if needed
        if 'machines' in spec_variables:
            for name in spec_variables['machines']:
                if 'image_name' not in spec_variables['machines'][name]:
                    spec_variables['machines'][name]['image_name'] = os_default

    # azure allows for an ssh_user, discarded in terraform spec for aws and gcloud
    # use 'ssh_user' per kubernetes cluster
    if 'ssh_user' in spec_variables and 'kubernetes' in spec_variables:
        for name in spec_variables['kubernetes']:
            if 'ssh_user' not in spec_variables['kubernetes'][name]:
                spec_variables['kubernetes'][name]['ssh_user'] = spec_variables['ssh_user']

    # change to each region zones to handle the same zone defined multple times
    # previously the mappings were defined as zones, ex. us-west-2a: 10.0.0.0/24
    # terraform variable: optional(map(string)) -> optional(map(object))
    # use 'zone_name' with machines and google kubernetes to track the zone wanted for use
    if 'regions' in spec_variables:
        for region in spec_variables['regions']:
            # check if all zones defined with a string
            # compatability skipped otherwise
            if 'zones' in spec_variables['regions'][region] and \
                isinstance(spec_variables['regions'][region]['zones'], dict) and \
                all([isinstance(item, str) for _, item in spec_variables['regions'][region]['zones'].items()]):
                temp = {}
                for zone, cidr in spec_variables['regions'][region]['zones'].items():
                    temp[f'depreciated-{zone}'] = {
                        'zone': zone,
                        'cidr': cidr,
                    }
                spec_variables['regions'][region]['zones'] = temp

    if 'machines' in spec_variables:
        for machine in spec_variables['machines']:
            if 'zone_name' not in spec_variables['machines'][machine] and 'zone' in spec_variables['machines'][machine]:
                spec_variables['machines'][machine]['zone_name'] = f'depreciated-{spec_variables["machines"][machine]["zone"]}'

    if 'kubernetes' in spec_variables:
        for cluster in spec_variables['kuberenetes']:
            if 'zone_name' not in spec_variables['kubernetes'][cluster] and 'zone' in spec_variables['kubernetes'][cluster]:
                spec_variables['kubernetes'][cluster]['zone_name'] = f'depreciated-{spec_variables["kubernetes"][machine]["zone"]}'

    return spec_variables
