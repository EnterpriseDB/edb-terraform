# coding: utf-8

import argparse
import json
from pathlib import Path, PurePath
import os
import sys
import shutil
import yaml

from jinja2 import Environment, FileSystemLoader

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.backends import default_backend


def tpl(template_name, dest, csp, vars={}):
    # Renders and saves a jinja2 template based on a given template name and
    # variables.

    try:
        # Templates are located in __file__/data/templates
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
        shutil.copytree(script_dir / 'data' / 'terraform' / csp, dir)
    except Exception as e:
        sys.exit("ERROR: cannot create project directory %s (%s)" % (dir, e))


def load_infra_file(file_path, csp):
    # Load the infrastructure file, expected format is YAML.

    if not os.path.exists(file_path):
        sys.exit("ERROR: file %s not found" % file_path)

    try:
        with open(file_path) as f:
            vars = yaml.load(f.read(), Loader=yaml.CLoader)
            if csp not in vars:
                sys.exit(
                    "ERROR: key '%s' not present in the infrastructure file."
                    % csp
                )
            # Returns CSP variables and cluster_name
            new_vars = vars[csp].copy()
            new_vars['cluster_name'] = vars['cluster_name']

            return new_vars
    except Exception as e:
        sys.exit("ERROR: could not read file %s (%s)" % (file_path, e))


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

def build_vars(csp, infra_vars, ssh_priv_key, ssh_pub_key):

    # Based on the infra variables, returns a tuple composed of (terraform
    # variables as a dist, template variables as a dict)

    # Variables used in the template files
    template_vars = {}
    # Starting with making a copy of infra_vars as our terraform_vars dict
    terraform_vars = infra_vars.copy()

    # Add additional terraform variables
    terraform_vars.update(dict(
        ssh_user=infra_vars.get('ssh_user', None),
        ssh_priv_key=ssh_priv_key,
        ssh_pub_key=ssh_pub_key,
        machines=infra_vars.get('machines', dict()),
        gke=infra_vars.get('gke', dict()),
        databases=infra_vars.get('databases', dict()),
        regions=infra_vars.get('regions', dict()),
        operating_system=infra_vars.get('operating_system', None),
    ))

    # Build template variables
    template_vars.update(dict(
        has_region_peering=(len(terraform_vars['regions'].keys()) > 1),
        has_machines=('machines' in infra_vars),
        has_gke=('gke' in infra_vars),
        has_databases=('databases' in infra_vars),
        has_regions=('regions' in infra_vars),
        regions=terraform_vars['regions'].copy(),
        peers=regions_to_peers(terraform_vars['regions']),
        machine_regions=object_regions('machines', terraform_vars),
        database_regions=object_regions('databases', terraform_vars),
    ))

    if csp == 'aws':
        return aws_build_vars(infra_vars, terraform_vars, template_vars)
    
    if csp == 'gcloud':
        return gcloud_build_vars(infra_vars, terraform_vars, template_vars)
    
    return (terraform_vars, template_vars)

def gcloud_build_vars(infra_vars, terraform_vars, template_vars):
    # Add additional terraform variables
    terraform_vars.update(dict(
        alloy=infra_vars.get('alloy', dict()),
        gke=infra_vars.get('gke', dict()),
    ))

    # Build template variables
    template_vars.update(dict(
        has_alloy=('alloy' in infra_vars),
        alloy_regions=object_regions('alloy', terraform_vars),
        has_gke=('gke' in infra_vars),
        gke_regions=object_regions('gke', terraform_vars),
    ))

    return (terraform_vars, template_vars)

def aws_build_vars(infra_vars, terraform_vars, template_vars):
    # Based on the infra variables, returns a tuple composed of (terraform
    # variables as a dist, template variables as a dict)

    # Add additional terraform variables
    terraform_vars.update(dict(
        aurora=infra_vars.get('aurora', dict()),
    ))

    # Build template variables
    template_vars.update(dict(
        has_aurora=('aurora' in infra_vars),
        aurora_regions=object_regions('aurora', terraform_vars),
    ))

    return (terraform_vars, template_vars)


def new_project_main():
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
    env = parser.parse_args()

    # Load infrastructure variables from the YAML file that was passed
    infra_vars = load_infra_file(env.infra_file, env.csp)

    # Duplicate terraform code into target project directory
    create_project_dir(env.project_path, env.csp)

    # Generate SSH keys if ssh_user is set
    ssh_priv_key = None
    ssh_pub_key = None
    if 'ssh_user' in infra_vars:
        # Generate a new SSH key pair
        (ssh_priv_key, ssh_pub_key) = generate_ssh_key_pair(env.project_path)
        ssh_priv_key = str(ssh_priv_key.resolve())
        ssh_pub_key = str(ssh_pub_key.resolve())

    # Transform variables extracted from the infrastructure file into
    # terraform and templates variables.
    (terraform_vars, template_vars) = \
        build_vars(env.csp, infra_vars, ssh_priv_key, ssh_pub_key)

    # Save terraform vars file
    save_terraform_vars(
        env.project_path, 'terraform_vars.json', terraform_vars
    )

    # Generate the main.tf and providers.tf files.
    tpl(
        'main.tf.j2',
        env.project_path / 'main.tf',
        env.csp,
        template_vars
    )
    tpl(
        'providers.tf.j2',
        env.project_path / 'providers.tf',
        env.csp,
        template_vars
    )