import argparse # More flexibilty for arguments.
from glob import glob # Add support to do multiple files with partial filemask.
import re

def make_arg_parser():
    parser = argparse.ArgumentParser(description="""
        A script to extract rows specifically for vendor only, for a given customer.
        
        Examples:
            python commingled_file_parser.py -m INPUT_FILE*.txt -c "CODE"
    """)
    parser.add_argument('-m', '--mask', help='The base filename mask. Can include wildcards (e.g., "*").', required=True)
    parser.add_argument('-c', '--code', help='The specific code for the customer.', required=True)
    parser.add_argument('-p', '--path', help='The full file path.', required=False, default='C:/')    
    return parser.parse_args()

def list_files(mask: str, path: str) -> list:
    """Use glob library so that we can easily parse wildcards for flexible batch script automation."""
    path = re.sub(r'\\', r'/', (lambda x: path if path[-1] != '\\' else path[:-1])(path))
    return glob(f'{path}/{mask}')

def get_code_pattern(code: str, kind: str) -> re.Pattern:
    """Each customer using the vendor feed has their data "bounded" by a "customer header" (CH) row and a "customer trailer" (CT) row."""
    p = {
        'start': f'^CH.*{code}',
        'end': f'^CT.*{code}'
    }
    return re.compile(p[kind])

def get_index(contents: list, code: str) -> int:
    """Get the index of the customer header for a given code. If none is found, return -1."""
    pattern = get_code_pattern(code, 'start')
    for i, v in enumerate(contents):
        if pattern.search(v) is not None:
            return i
    return -1

def extract_records(fullpath: str, code: str) -> list:
    """Retrieve the content from each file and load it into a string. Also parse the data for the specific customer code."""
    with open(fullpath, 'r') as i:
        content = list(i.read().splitlines())
        ind = get_index(content, code) + 1
        end = get_code_pattern(code, 'end')
        
        records = []
        while end.search(content[ind]) is None:
            records.append(content[ind])
            ind += 1
        return records

def filter_records(records: list) -> list:
    """Filter only "data" row two (2) and greater records; row one (1) only provides account number information."""
    row_start = re.compile(r'D10[2-9]{1}0101')
    return list(filter(lambda x: x if row_start.search(x) is not None else None, records))

def parse_records(records: list) -> dict:
    """Parse the records into a dictionary."""
    def _remove_whitespace(name: str) -> str:
        """For when str.strip() is not enough! Removes all whitespace from a string, even additional whitespace within."""
        return ' '.join(name.split())

    r = {}
    for i, v in enumerate(records):
        r[i] = {
            'account_provider_name': 'vendor',
            'account_number': v[8:17],
            'account_holder_1': _remove_whitespace(v[23:90]),
            'account_holder_2': _remove_whitespace(v[113:181]),
            'account_holder_other': _remove_whitespace(v[204:272])
        }
    return r

def make_file(fullpath: str, content: dict, code: str):
    """Create a file of the parsed data."""
    with open(f'{fullpath}.{code}.txt', 'w') as o:
        o.write('{0}\n'.format('|'.join(content[0].keys())))
        for i in content:
            o.write('{0}\n'.format('|'.join(content[i].values())))

def main(parameters):
    for files in list_files(parameters.mask, parameters.path):
        contents = extract_records(files, parameters.code)
        filtered = filter_records(contents)
        parsed = parse_records(filtered)
        make_file(files, parsed, parameters.code)
main(make_arg_parser())