# coding: utf-8

import argparse
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


def generate_ssh_key_pair(dir):
    # Generates and saves a pair of SSH keys.
    # Returns a tuple composed of the private and public keys file paths.

    # Generate a 2048 bits private key using RSA
    key = rsa.generate_private_key(
        backend=default_backend(),
        public_exponent=65537,
        key_size=2048
    )

    b_private_key = key.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.TraditionalOpenSSL,
        serialization.NoEncryption()
    )

    b_public_key = key.public_key().public_bytes(
        serialization.Encoding.OpenSSH,
        serialization.PublicFormat.OpenSSH
    )

    try:
        # Save the private key content.
        priv_key_path = dir / "ssh-id_rsa"
        with open(priv_key_path, 'wb') as f:
            f.write(b_private_key)
        # Make sure the file privileges are ok for SSH.
        os.chmod(priv_key_path, 0o600)
    except Exception as e:
        sys.exit("ERROR: could not write %s (%s)" % (priv_key_path, e))

    try:
        # Save the public key content.
        pub_key_path = dir / "ssh-id_rsa.pub"
        with open(pub_key_path, 'wb') as f:
            f.write(b_public_key + b'\n')
    except Exception as e:
        sys.exit("ERROR: could not write %s (%s)" % (pub_key_path, e))

    return (priv_key_path, pub_key_path)


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

def build_vars(csp, infra_vars, project_path):

    # Based on the infra variables, returns a tuple composed of (terraform
    # variables as a dist, template variables as a dict)

    # Get a spec compatable object
    infra_vars = spec_compatability(infra_vars, csp)

    # Generate SSH keys if ssh_user is set
    ssh_priv_key = None
    ssh_pub_key = None
    if 'ssh_user' in infra_vars:
        # Generate a new SSH key pair
        (ssh_priv_key, ssh_pub_key) = generate_ssh_key_pair(project_path)
        ssh_priv_key = str(ssh_priv_key.resolve())
        ssh_pub_key = str(ssh_pub_key.resolve())

    # Variables used in the template files
    # Build jinja template variable
    template_vars = dict(
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
        ssh_priv_key = ssh_priv_key,
        ssh_pub_key = ssh_pub_key,
    )
    
    return (terraform_vars, template_vars)

def new_project_main(args=None):
    # Main function of the edb-terraform script.

    parser = argparse.ArgumentParser()
    parser.add_argument(
        'project_path',
        metavar='PROJECT_PATH',
        type=Path,
        help="Project path.",
    )
    parser.add_argument(
        'infra_file',
        metavar='INFRA_FILE_YAML',
        type=Path,
        help="CSP infrastructure (YAML format) file path."
    )
    parser.add_argument(
        '--cloud-service-provider', '-c',
        metavar='CLOUD_SERVICE_PROVIDER',
        dest='csp',
        choices=['aws', 'gcloud', 'azure'],
        default='aws',
        help="Cloud Service Provider. Default: %(default)s"
    )
    parser.add_argument(
        '--validate',
        dest='run_validation',
        action='store_true',
        required=False,
        help='''
            Requires terraform >= 1.3.6
            Validates the generated files by running:
            `terraform apply -target=null_resource.validation`
            If invalid, error will be displayed and project directory destroyed
            Default: %(default)s
            '''
    )
    env = parser.parse_args(args=args)
    generate_terraform(env.infra_file, env.project_path, env.csp, env.run_validation)

def generate_terraform(infra_file, project_path, csp, run_validation):
    # Load infrastructure variables from the YAML file that was passed
    infra_vars = load_yaml_file(infra_file)

    # Duplicate terraform code into target project directory
    create_project_dir(project_path, csp)

    # Transform variables extracted from the infrastructure file into
    # terraform and templates variables.
    (terraform_vars, template_vars) = \
        build_vars(csp, infra_vars, project_path)

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

    run_terraform(project_path, run_validation)

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

    if cloud_service_provider not in infrastructure_variables:
        sys.exit(
                    "ERROR: key '%s' not present in the infrastructure file."
                    % cloud_service_provider
                )
    
    spec_variables = infrastructure_variables[cloud_service_provider].copy()
    
    # Users were able to use 'cluster_name' at the same level as cloud_service_provider before
    if 'tags' not in spec_variables:
        spec_variables['tags'] = dict()
    if 'cluster_name' not in spec_variables['tags'] and \
        'cluster_name' in infrastructure_variables:
        spec_variables['tags']['cluster_name'] = infrastructure_variables['cluster_name']

    replace_pairs = {
        # Modules used to expect azs and az
        "azs": "zones",
        "az": "zone",
    }
    spec_variables = change_keys(spec_variables, replace_pairs)

    return spec_variables
