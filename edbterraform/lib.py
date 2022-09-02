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


def tpl(template_name, dest, vars={}):
    # Renders and saves a jinja2 template based on a given template name and
    # variables.

    try:
        # Templates are located in __file__/data/templates
        current_dir = Path(__file__).parent.resolve()
        templates_dir = PurePath.joinpath(current_dir, 'data', 'templates')

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


def load_infra_file(file_path):
    # Load the infrastructure file, expected format is YAML.

    if not os.path.exists(file_path):
        sys.exit("ERROR: file %s not found" % file_path)

    try:
        with open(file_path) as f:
            return yaml.load(f.read(), Loader=yaml.CLoader)
    except Exception as e:
        sys.exit("ERROR: could not read file %s (%s)" % (file_path, e))


def to_terraform_vars(dir, filename, vars):
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
        choices=['aws'],
        default='aws',
        help="Cloud Service Provider. Default: %(default)s"
    )
    env = parser.parse_args()

    # Duplicate terraform code into target project directory
    create_project_dir(env.project_path, env.csp)

    # Load infrastructure variable from the YAML file that was passed
    vars = load_infra_file(env.infra_file)
    # Variables used in the template files
    template_vars = {}

    if 'ssh_user' in vars:
        # Generate a new SSH key pair
        (ssh_priv_key, ssh_pub_key) = generate_ssh_key_pair(env.project_path)
        # Inject SSH variables
        vars['ssh_priv_key'] = str(ssh_priv_key.resolve())
        vars['ssh_pub_key'] = str(ssh_pub_key.resolve())
    else:
        # When ssh_user is not set in the infrastructure file, then initialize
        # the terraform vars related to SSH setup to None. They must be passed
        # to terraform even in this case.
        vars['ssh_user'] = None
        vars['ssh_priv_key'] = None
        vars['ssh_pub_key'] = None

    # Set default empty values if they are not set, this is required by
    # the terraform part.
    if 'machines' not in vars:
        vars['machines'] = dict()
        template_vars['has_machine'] = False
    else:
        template_vars['has_machine'] = True

    if 'databases' not in vars:
        vars['databases'] = dict()
        template_vars['has_database'] = False
    else:
        template_vars['has_database'] = True

    if 'aurora' not in vars:
        vars['aurora'] = dict()
        template_vars['has_aurora'] = False
    else:
        template_vars['has_aurora'] = True

    if 'operating_system' not in vars:
        vars['operating_system'] = None

    if 'regions' not in vars:
        vars['regions'] = dict()
        template_vars['has_network'] = False
    else:
        template_vars['has_network'] = True

    if len(vars['regions'].keys()) > 1:
        template_vars['has_region_peering'] = True
    else:
        template_vars['has_region_peering'] = False

    # Transform infrastructure configuration to terraform variables
    to_terraform_vars(env.project_path, 'terraform_vars.json', vars)

    # Build template variables
    template_vars['regions'] = vars['regions'].copy()
    template_vars['peers'] = regions_to_peers(vars['regions'])
    template_vars['machine_regions'] = object_regions('machines', vars)
    template_vars['database_regions'] = object_regions('databases', vars)
    template_vars['aurora_regions'] = object_regions('aurora', vars)

    # Generate the main.tf and providers.tf files.
    tpl('main.tf', env.project_path / 'main.tf', template_vars)
    tpl('providers.tf.j2', env.project_path / 'providers.tf', template_vars)
