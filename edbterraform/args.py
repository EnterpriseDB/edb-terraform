import sys
import argparse
from pathlib import Path
import textwrap

from edbterraform.lib import generate_terraform
from edbterraform.CLI import TerraformCLI
from edbterraform import __project_name__
from edbterraform.Logger import logger

class Arguments:

    COMMANDS = ['generate', 'setup']
    DEFAULT_COMMAND = COMMANDS[0]

    def __init__(self, args:list[str]=sys.argv, parser=argparse.ArgumentParser()):
        self.parser = parser
        self.subparsers = self.parser.add_subparsers()
        self.command = self.override_sys_argv(args)

        for command in Arguments.COMMANDS:
            self.subparsers.add_parser(command)
        self.subparsers.default = Arguments.DEFAULT_COMMAND

        generate = self.subparsers.choices['generate']
        generate.add_argument(
            'project_path',
            metavar='PROJECT_PATH',
            type=Path,
            help="Project path.",
        )
        generate.add_argument(
            'infra_file',
            metavar='INFRA_FILE_YAML',
            type=Path,
            help="CSP infrastructure (YAML format) file path."
        )
        generate.add_argument(
            '--cloud-service-provider', '-c',
            metavar='CLOUD_SERVICE_PROVIDER',
            dest='csp',
            choices=['aws', 'gcloud', 'azure'],
            default='aws',
            help="Cloud Service Provider. Default: %(default)s"
        )
        generate.add_argument(
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
        generate.add_argument(
            '--bin_path',
            dest='bin_path',
            default=TerraformCLI.DEFAULT_PATH,
            required=False,
            help='''
                Default location to install binaries.
                It will default to users home directory.
                Default: %(default)s
                '''
        )
        setup = self.subparsers.choices['setup']
        setup.add_argument(
            '--bin_path',
            dest='bin_path',
            default=TerraformCLI.DEFAULT_PATH,
            required=False,
            help='''
                Default location to install binaries.
                It will default to users home directory.
                Default: %(default)s
                '''
        )

        self.env = self.parser.parse_args()

    def override_sys_argv(self, args: list[str]):
        '''
        Override sys.argv and return the default command
        This is needed for backwards compatability,
        as we did not have multiple commands previously.
        '''
        # Set default subparser if not provided
        sys.argv = args
        program_name = self.parser.prog
        program_index = 0
        command_index = program_index+1

        for index, argument in enumerate(sys.argv):
            if argument == program_name:
                program_index = index
                command_index = index+1
                break

        # Set default if not provided
        if program_index < len(sys.argv)-1 and \
            sys.argv[command_index] not in Arguments.COMMANDS and \
            sys.argv[command_index] not in ['-h', '--help']:
            sys.argv.insert(command_index, Arguments.DEFAULT_COMMAND)
            return sys.argv[command_index]
        # Set help if not provided
        elif program_index == len(sys.argv)-1:
            sys.argv.insert(command_index, '-h')
            return sys.argv[command_index]
        elif program_index < len(sys.argv)-1:
            return sys.argv[command_index]

        return sys.argv[program_index]

    def process_args(self):
        if self.command == 'generate':
            outputs = generate_terraform(
                self.env.infra_file,
                self.env.project_path,
                self.env.csp,
                self.env.run_validation,
                self.env.bin_path,
            )
            logger.info(textwrap.dedent('''
            Success!
            You can use now use terraform and see info about your boxes after creation:
            * cd {project_path}
            * terraform init
            * terraform apply -auto-approve
            * terraform output -json {output_key}
            * ssh <ssh_user>@<ip-address> -i {ssh_file}
            ''').format(
                project_path = self.env.project_path,
                output_key = outputs['terraform_output'],
                ssh_file = outputs['ssh_filename'],
            ))
            return outputs

        if self.command == 'setup':
            terraform = TerraformCLI(self.env.bin_path)
            terraform.install()
            return terraform.bin_path
