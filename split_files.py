import argparse # More flexibilty for arguments.
from glob import glob # Add support to do multiple files with partial filemask.
import re

def make_arg_parser():
    parser = argparse.ArgumentParser(description="""
        Splits the file into a header file, trailer file and details file.

        Example usage: python split_file.py -ma "*Filename_Mask*.txt" -he 1 -ta 1
    """)
    parser.add_argument('-ma', '--mask', help='The base filename mask. Can include wildcards (e.g., "*").', required=True)
    parser.add_argument('-pa', '--path', help='The full file path.', required=False, default='C:/')
    parser.add_argument('-he', '--head', help='The number of header rows.', required=False, default=0)
    parser.add_argument('-ta', '--tail', help='The number of trailer rows. Please use a positive integer.', required=False, default=0)
    return parser.parse_args()

def convert_args_to_dict(args) -> dict:
    """Convert arguments provided by make_arg_parser() into easily accessible dict with some basic transformations."""
    def _convert_slice_index(n: str, trailer: bool=False) -> int:
        n = int(n)
        if n == 0:
            n = None
        elif n > 0 and trailer:
            n = -1 * int(n)
        return n
    
    h = _convert_slice_index(args.head)
    t = _convert_slice_index(args.tail, True)

    return {
        'mask': args.mask,
        'path': args.path,
        'headers': h,
        'trailers': t
    }

def list_files(mask: str, path: str) -> list:
    """Use glob library so that we can easily parse wildcards for flexible batch script automation."""
    path = re.sub(r'\\', r'/', (lambda x: path if path[-1] != '\\' else path[:-1])(path))
    return glob(f'{path}/{mask}')

def fetch_content(args: dict, fullpath: str, c: dict={}) -> dict:
    """Retrieve the content from each file and load it into a dictionary for easy access."""
    with open(fullpath, 'r') as i:
        content = list(i.read().splitlines())
        c['header'] = content[ : args['headers'] ]
        c['trailer'] = content[ args['trailers'] : ]
        c['data'] = content[ args['headers'] : args['trailers'] ]
        return c

def split_files(fullpath: str, content: dict):
    """Split the input file into multiple files."""
    for c in content:
        with open(f'{fullpath}.{c}.txt', 'w') as o:
            o.write('\n'.join(content[c]))

def main(parameters):
    args = convert_args_to_dict(parameters)
    for files in list_files(args['mask'], args['path']):
        contents = fetch_content(args, files)
        split_files(files, contents)

main(make_arg_parser())