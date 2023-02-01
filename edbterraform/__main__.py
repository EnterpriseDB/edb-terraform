import sys
import argparse
from pathlib import Path
try:
    from edbterraform.lib import generate_terraform
except:
    from lib import generate_terraform

class Arguments:
    def __init__(self):
        self.parser = argparse.ArgumentParser()
        self.parser.add_argument(
            'project_path',
            metavar='PROJECT_PATH',
            type=Path,
            help="Project path.",
        )
        self.parser.add_argument(
            'infra_file',
            metavar='INFRA_FILE_YAML',
            type=Path,
            help="CSP infrastructure (YAML format) file path."
        )
        self.parser.add_argument(
            '--cloud-service-provider', '-c',
            metavar='CLOUD_SERVICE_PROVIDER',
            dest='csp',
            choices=['aws', 'gcloud', 'azure'],
            default='aws',
            help="Cloud Service Provider. Default: %(default)s"
        )
        self.parser.add_argument(
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

def main(args=None):
    env = Arguments().parser.parse_args(args)
    output_variable = generate_terraform(env.infra_file, env.project_path, env.csp, env.run_validation)
    sys.stdout.write(f'''
    Success!
    You can use now use terraform and see info about your boxes after creation:
    * cd {env.project_path}
    * terraform apply
    * terraform output -json {output_variable}
    \n
    ''')
    
    return output_variable

if __name__ == '__main__':
    main()
