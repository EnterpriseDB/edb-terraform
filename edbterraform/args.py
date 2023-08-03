import sys
import os
import argparse
from pathlib import Path
import textwrap
from dataclasses import dataclass, field
from collections import OrderedDict
from typing import List
from datetime import datetime

from edbterraform.lib import generate_terraform
from edbterraform.CLI import TerraformCLI
from edbterraform import __project_name__, __dot_project__, __version__
from edbterraform.utils import logs

ENVIRONMENT_PREFIX = 'ET_' # Appended to allow overrides of defaults

@dataclass
class ArgumentConfig:
    '''
    Dataclass meant to represent an object for argparse arguments.
    Ex:
    config = ArgumentConfig(names=['--test'], dest='test', required=False)
    subparser.add_argument(
        *(config.get_names()),
        **(config.get_args())
    )
    '''
    names: tuple = None
    metavar: str = None
    dest: str = None
    type: type = None
    help: str = ''
    default: str = None
    choices: list = None
    required: bool = None
    action: str = None
    nargs: str = None

    def __post_init__(self) -> None:
        # Allow overriding of variables with environment variables
        self.default = os.getenv(self.default_env_var(), self.default)
        self.help += f'''
        | Default Environment variable: {self.default_env_var()}
        '''

        tempdict = self.__dict__.items()
        # dictionary with non-None values
        self.filtered_dict = {k: v for k, v in tempdict if k != 'names' and v is not None}

    def default_env_var(self) -> str:
        '''
        Get a default environment variable to check for overrides.
        Priority:
        1. dest variable
        2. Uses longest command to create environment variable

        Returns ET_{command_name}
        '''
        name = ''
        if self.dest:
            name = self.dest
        else:
            name = max(self.names, key=len)

        return ENVIRONMENT_PREFIX + name.lstrip('-').replace('-', '_').upper()

    def get_args(self):
        return self.filtered_dict

    def get_names(self):
        return self.names

    def __getitem__(self, key):
        return self.filtered_dict.get(key, None)

BinPath = ArgumentConfig(
    names = ['--bin-path'],
    dest  = 'bin_path',
    default = TerraformCLI.DEFAULT_PATH,
    required = False,
    help = '''
            Default location to install binaries.
            It will default to users home directory.
            Default: %(default)s
           ''',
)

ProjectPathDepreciated = ArgumentConfig(
    names = ['project_path',],
    metavar='PROJECT_PATH',
    type=Path,
    help="Project path. Default: %(default)s",
)

InfraFileDepreciated = ArgumentConfig(
    names = ['infra_file',],
    metavar='INFRA_FILE_YAML',
    type=Path,
    help="CSP infrastructure (YAML format) file path. Default: %(default)s"
)

WorkPath = ArgumentConfig(
    names = ['--work-path',],
    metavar='WORK_PATH',
    dest='work_path',
    type=Path,
    default=Path.cwd(),
    required=False,
    help="Project path. Default: %(default)s",
)

UserTemplatesPath = ArgumentConfig(
    names = ['--user-templates',],
    metavar='USER_TEMPLATE_FILES',
    dest='user_templates',
    type=Path,
    nargs='+',
    required=False,
    default=[f'{__dot_project__}/templates',],
    help="Users can pass in a list of template files or template directories, which will be rendered with the servers output. Default: %(default)s",
)

InfrastructureFilePath = ArgumentConfig(
    names = ['--infra-file',],
    metavar='INFRA_FILE_YAML',
    dest='infra_file',
    type=Path,
    required=True,
    help="cloud service provider infrastructure file path (YAML format). Default: %(default)s"
)

TerraformLockHcl = ArgumentConfig(
    names = ['--lock-hcl-file',],
    metavar='LOCK_HCL_FILE',
    dest='lock_hcl_file',
    type=Path,
    required=False,
    help='''
    Terraform Lock HCL file is used to ensure the same package versions are used across architectures with terraform's cli.
    If not used, terraform will try to grab the latest versions from each provider.
    Default: %(default)s
    '''
)

class ProjectNameAction(argparse.Action):
    '''
    project name might be combined with Path
    and should avoid setting leading slashes: '/'
    During conatentation, Path will return the second value if it is a root path.
    '''
    def __call__(self, parser, namespace, values, option_string=None):
        new_value = values.lstrip('\\/')
        setattr(namespace, self.dest, new_value)

ProjectName = ArgumentConfig(
    names = ['--project-name',],
    metavar='PROJECT_NAME',
    dest='project_name',
    required=True,
    action=ProjectNameAction,
    help='''
        Creates a directory with PROJECT_NAME for generated files in the WORK_PATH.
        Leading slashes will be removed from names.
        Default: %(default)s
        '''
)

CloudServiceProvider = ArgumentConfig(
    names = ['--cloud-service-provider', '-c',],
    metavar='CLOUD_SERVICE_PROVIDER',
    dest='csp',
    choices=['aws', 'gcloud', 'azure'],
    default='aws',
    help="Cloud Service Provider. Default: %(default)s"
)

Validation = ArgumentConfig(
    names = ['--validate',],
    dest='run_validation',
    action='store_true',
    required=False,
    default=False,
    help='''
        Requires terraform >= 1.3.6
        Validates the generated files by running:
        `terraform apply -target=null_resource.validation`
        If invalid, error will be displayed and project directory destroyed
        Default: %(default)s
        '''
)

Apply = ArgumentConfig(
    names = ['--apply',],
    dest='apply',
    action='store_true',
    required=False,
    default=False,
    help='''
        Requires terraform >= 1.3.6
        `terraform apply`
        If invalid, error will be displayed and project directory destroyed
        Default: %(default)s
        '''
)

Destroy = ArgumentConfig(
    names = ['--destroy',],
    dest='destroy',
    action='store_true',
    required=False,
    default=False,
    help='''
        Requires terraform >= 1.3.6
        Attempt to remove an existing project before creating a new one.
        If invalid, error will be displayed and project directory destroyed
        Default: %(default)s
        '''
)

LogLevel = ArgumentConfig(
    names = ['--log-level',],
    dest='log_level',
    required=False,
    default="INFO",
    help='''
        Default: %(default)s
        '''
)

LogFile = ArgumentConfig(
    names = ['--log-file',],
    dest='log_file',
    required=False,
    default=datetime.now().strftime('%Y-%m-%d'),
    help='''
        Default: %(default)s
        '''
)

LogDirectory = ArgumentConfig(
    names = ['--log-directory',],
    dest='log_directory',
    required=False,
    default=f'{__dot_project__}/logs',
    help='''
        Default: %(default)s
        '''
)

LogStdout = ArgumentConfig(
    names = ['--log-stdout',],
    dest='log_stdout',
    action='store_true',
    required=False,
    default=True,
    help='''
        Default: %(default)s
        '''
)

class Arguments:

    # Command, description, and its options
    COMMANDS = OrderedDict({
        'depreciated': ['Depreciated call for generating terraform files\n', [
            ProjectPathDepreciated,
            InfraFileDepreciated,
            CloudServiceProvider,
            Validation,
            BinPath,
            LogLevel,
            LogFile,
            LogDirectory,
            LogStdout,
        ]],
        'generate': ['Generate terraform files based on a yaml infrastructure file\n',[
            ProjectName,
            InfrastructureFilePath,
            WorkPath,
            CloudServiceProvider,
            Validation,
            Apply,
            Destroy,
            BinPath,
            LogLevel,
            LogFile,
            LogDirectory,
            LogStdout,
            UserTemplatesPath,
            TerraformLockHcl,
        ]],
        'setup': ['Install needed software such as Terraform inside a bin directory\n',[
            BinPath,
            LogLevel,
            LogFile,
            LogDirectory,
            LogStdout,
        ]],
    })
    DEFAULT_COMMAND = next(iter(COMMANDS))
    VERSION_MESSAGE=f'Version: {__version__}\n'

    def __init__(self, args:List[str]=sys.argv, parser=argparse.ArgumentParser()):
        self.parser = parser
        self.subparsers = self.parser.add_subparsers()
        self.command = self.override_sys_argv(args)
        self.subparsers.default = Arguments.DEFAULT_COMMAND

        for name, arg_configs in self.COMMANDS.items():
            self.subparsers.add_parser(name)
            subparser = self.subparsers.choices[name]
            for config in arg_configs[1]:
                subparser.add_argument(
                    *(config.get_names()),
                    **(config.get_args())
                )
            subparser.usage = arg_configs[0]+self.VERSION_MESSAGE+subparser.format_usage()

        self.env = self.parser.parse_args()

    def override_sys_argv(self, args: List[str]):
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

    def get_env(self, key, default=None):
        '''
        Get environment variables which are available after parse_args() is called
        '''
        return getattr(self.env, key, default)
    
    def get_kwargs(self):
        '''
        Returns the parsed arguments as a dictionary.
        _get_kwargs not used as it returns a list of dictionary items.
        '''
        return self.env.__dict__.copy()

    def process_args(self):
        logs.setup_logs(
            level=self.get_env('log_level'),
            file_name=self.get_env('log_file'),
            directory=self.get_env('log_directory'),
            stdout=self.get_env('log_stdout'),
        )
        if self.command == 'depreciated':
            outputs = generate_terraform(
                self.get_env('infra_file'),
                self.get_env('project_path'),
                self.get_env('csp'),
                self.get_env('bin_path'),
                self.get_env('run_validation'),
            )

        if self.command == 'generate':
            outputs = generate_terraform(
                self.get_env('infra_file'),
                self.get_env('work_path') / self.get_env('project_name'),
                self.get_env('csp'),
                self.get_env('bin_path'),
                self.get_env('user_templates'),
                self.get_env('lock_hcl_file'),
                self.get_env('run_validation'),
                self.get_env('apply'),
                self.get_env('destroy'),
            )
            return outputs

        if self.command == 'setup':
            terraform = TerraformCLI(self.get_env('bin_path'))
            terraform.install()
            return terraform.bin_path
