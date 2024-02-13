import sys
import os
import argparse
from pathlib import Path
import textwrap
from dataclasses import dataclass, field
from collections import OrderedDict
from typing import List
from datetime import datetime
from functools import partial
import json

from edbterraform.lib import generate_terraform
from edbterraform.CLI import TerraformCLI, JqCLI, AwsCLI, AzureCLI, GoogleCLI, BigAnimalCLI
from edbterraform import __project_name__, __dot_project__, __version__
from edbterraform.utils import logs, files

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
    default = __dot_project__,
    required = False,
    help = '''
            Default location to install/check binaries.
            When using the default, it will be updated per tool under $HOME/.edb-terraform/<TOOLNAME>/<VERSION>/bin/<TOOLNAME>
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
    help="cloud service provider infrastructure file path (YAML format) or a jinja2 template with a top level object. Default: %(default)s"
)

InfrastructureTemplateVariables = ArgumentConfig(
    names = ['--infra-template-variables',],
    metavar='INFRA_TEMPLATE_VARIABLES',
    dest='infra_template_variables',
    default='{}',
    type=files.load_yaml_file,
    required=False,
    help="Infrastructure variables file path or a string representing yaml or json with a top level object. Only used when the infrastructure file is a jinja2 template. Default: %(default)s"
)

RemoteStateType = ArgumentConfig(
    names = ['--remote-state-type',],
    metavar='REMOTE_STATE_TYPE',
    dest='remote_state_type',
    type=str,
    default='local',
    help="""
    When state is not set to `local`,
      force configuration of backend with `terraform init -backend-config="<KEY=VALUE | FILEPATH >"`.
    Use `cloud` to use the set cloud provider as the backend.
    Any other value can be passed as the backend type for use within providers.tf.json but will not be validated until `terraform init` is run.

    Default: %(default)s
    """
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

TerraformVersion = ArgumentConfig(
    names = [f'--{TerraformCLI.binary_name.lower()}-cli-version',],
    metavar=f'{TerraformCLI.binary_name.upper()}_CLI_VERSION',
    dest=f'{TerraformCLI.binary_name.lower()}_cli_version',
    required=False,
    default=TerraformCLI.max_version.to_string(),
    help=f'''
        Terraform version to install/use. Set to 0 to skip.
        Compatible versions: {TerraformCLI.min_version.to_string()} <= x <= {TerraformCLI.max_version.to_string()}
        Default: %(default)s
        '''
)

JqVersion = ArgumentConfig(
    names = [f'--{JqCLI.binary_name.lower()}-cli-version',],
    metavar=f'{JqCLI.binary_name.upper()}_CLI_VERSION',
    dest=f'{JqCLI.binary_name.lower()}_cli_version',
    required=False,
    default=JqCLI.max_version.to_string(),
    help=f'''
        JQ version to install or use. Set to 0 to skip.
        Compatible versions: {JqCLI.min_version.to_string()} <= x <= {JqCLI.max_version.to_string()}
        Default: %(default)s
        '''
)

AwsVersion = ArgumentConfig(
    names = [f'--{AwsCLI.binary_name.lower()}-cli-version',],
    metavar=f'{AwsCLI.binary_name.upper()}_CLI_VERSION',
    dest=f'{AwsCLI.binary_name.lower()}_cli_version',
    required=False,
    default=AwsCLI.max_version.to_string(),
    help=f'''
        AwsCLIv2 version to install or use. Set to 0 to skip.
        Compatible versions: {AwsCLI.min_version.to_string()} <= x <= {AwsCLI.max_version.to_string()}
        Default: %(default)s
        '''
)

AzureVersion = ArgumentConfig(
    names = [f'--{AzureCLI.binary_name.lower()}-cli-version',],
    metavar=f'{AzureCLI.binary_name.upper()}_CLI_VERSION',
    dest=f'{AzureCLI.binary_name.lower()}_cli_version',
    required=False,
    default=AzureCLI.max_version.to_string(),
    help=f'''
        AzureCLI version to install or use. Set to 0 to skip.
        Compatible versions: {AzureCLI.min_version.to_string()} <= x <= {AzureCLI.max_version.to_string()}
        Default: %(default)s
        '''
)

GcloudVersion = ArgumentConfig(
    names = [f'--{GoogleCLI.binary_name.lower()}-cli-version',],
    metavar=f'{GoogleCLI.binary_name.upper()}_CLI_VERSION',
    dest=f'{GoogleCLI.binary_name.lower()}_cli_version',
    required=False,
    default=GoogleCLI.max_version.to_string(),
    help=f'''
        GoogleCLI version to install or use. Set to 0 to skip.
        Compatible versions: {GoogleCLI.min_version.to_string()} <= x <= {GoogleCLI.max_version.to_string()}
        Default: %(default)s
        '''
)

BigAnimalVersion = ArgumentConfig(
    names = [f'--{BigAnimalCLI.binary_name.lower()}-cli-version',],
    metavar=f'{BigAnimalCLI.binary_name.upper()}_CLI_VERSION',
    dest=f'{BigAnimalCLI.binary_name.lower()}_cli_version',
    required=False,
    default=BigAnimalCLI.max_version.to_string(),
    help=f'''
        BigAnimalCLI version to install or use. Set to 0 to skip.
        Compatible versions: {BigAnimalCLI.min_version.to_string()} <= x <= {BigAnimalCLI.max_version.to_string()}
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
    help=f'''
        Requires terraform {TerraformCLI.min_version} <= x <= {TerraformCLI.max_version}
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
        Requires terraform {TerraformCLI.min_version} <= x <= {TerraformCLI.max_version}
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
        Requires terraform {TerraformCLI.min_version} <= x <= {TerraformCLI.max_version}
        Attempt to remove an existing project before creating a new one.
        If invalid, error will be displayed and project directory destroyed
        Default: %(default)s
        '''
)

LogLevel = ArgumentConfig(
    names = ['--log-level',],
    dest='log_level',
    required=False,
    default=logs.LogLevel.INFO,
    help=f'''
        Default: %(default)s |
        Options - {logs.LogLevel.available_options()}
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
    names = ['--no-console-log',],
    dest='no_console_log',
    action='store_true',
    required=False,
    default=False,
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
            TerraformVersion,
            JqVersion,
        ]],
        'generate': ['Generate terraform files based on a yaml infrastructure file\n',[
            ProjectName,
            InfrastructureFilePath,
            InfrastructureTemplateVariables,
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
            TerraformVersion,
            RemoteStateType,
        ]],
        'setup': ['Install needed software such as Terraform inside a bin directory\n',[
            BinPath,
            LogLevel,
            LogFile,
            LogDirectory,
            LogStdout,
            TerraformVersion,
            JqVersion,
            AwsVersion,
            AzureVersion,
            GcloudVersion,
            BigAnimalVersion,
        ]],
        'version': ['Print the version of edb-terraform\n', []],
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
        program_index = 0 # programs index
        command_index = program_index+1 # First argument after program name

        # Find the programs initial index since it may not be the first argument
        for index, argument in enumerate(sys.argv):
            if argument == program_name:
                program_index = index
                command_index = index+1
                break

        if program_index < len(sys.argv)-1 and \
            sys.argv[command_index] not in Arguments.COMMANDS and \
            not any(x in sys.argv for x in ['-h', '--help', '-v', '--version']):
            sys.argv.insert(command_index, Arguments.DEFAULT_COMMAND)
            return sys.argv[command_index]
        # Set help if seen
        elif program_index < len(sys.argv)-1 and \
            '-h' in sys.argv or '--help' in sys.argv:
            sys.argv = sys.argv[:command_index+1] + ['--help']
            return sys.argv[command_index]
        # Set version command if seen
        elif program_index < len(sys.argv)-1 and \
            '-v' in sys.argv or '--version' in sys.argv:
            sys.argv = sys.argv[:command_index] + ['version']
            return sys.argv[command_index]
        # Set help if no arguments are provided
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
        if self.command == 'version':
            outputs = __version__
            print(outputs)
            return outputs

        logs.setup_logs(
            level=self.get_env('log_level'),
            file_name=self.get_env('log_file'),
            directory=self.get_env('log_directory'),
            stdout=not self.get_env('no_console_log'),
        )
        if self.command == 'depreciated':
            outputs = generate_terraform(
                infra_file=self.get_env('infra_file'),
                project_path=self.get_env('project_path'),
                csp=self.get_env('csp'),
                bin_path=self.get_env('bin_path'),
                run_validation=self.get_env('run_validation'),
                terraform_version=self.get_env('terraform_version'),
            )

        if self.command == 'generate':
            outputs = generate_terraform(
                infra_file=self.get_env('infra_file'),
                infra_template_variables=self.get_env('infra_template_variables'),
                project_path=self.get_env('work_path') / self.get_env('project_name'),
                csp=self.get_env('csp'),
                bin_path=self.get_env('bin_path'),
                user_templates=self.get_env('user_templates'),
                hcl_lock_file=self.get_env('lock_hcl_file'),
                run_validation=self.get_env('run_validation'),
                apply=self.get_env('apply'),
                destroy=self.get_env('destroy'),
                remote_state_type = self.get_env('remote_state_type'),
                terraform_version=self.get_env('terraform_version'),
            )
            print(json.dumps(outputs, separators=(',', ':')))

        if self.command == 'setup':
            installed = {}
            for tool in [TerraformCLI, JqCLI, AwsCLI, AzureCLI, GoogleCLI, BigAnimalCLI]:
                name = tool.binary_name
                tool = tool(self.get_env('bin_path'), self.get_env(f'{name}_cli_version'))
                tool.install()
                installed[name] = str(tool.get_binary())
            print(json.dumps(installed, separators=(',', ':')))
            outputs = installed

        return outputs
