import sys
import os.path
# When invoked as a script, we need to add the package to the path,
# this is done to avoid needing to use try/except imports
if not __package__:
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from edbterraform.args import Arguments

def main(args=None):
    """ 
    args: can either be None or a list of arguments to be passed into parse_args

    Returns the dictionary from generate_terraform()
    """
    arg_parser = Arguments()
    outputs = arg_parser.process_args()
    return outputs

'''
Entry point made for setup.py to use
'''
def entry_point():
    main()

if __name__ == '__main__':
    entry_point()
