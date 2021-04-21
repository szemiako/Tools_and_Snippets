import os, re

def main():
    def _base_dir():
        return os.path.dirname(os.path.realpath(__file__))
    
    rootdir = '{0}/mask/'.format(_base_dir())
    
    masking_cipher = {
        "A" : "X", 
        "B" : "X", 
        "C" : "X", 
        "D" : "X", 
        "E" : "X", 
        "F" : "X", 
        "G" : "X", 
        "H" : "X", 
        "I" : "X", 
        "J" : "X", 
        "K" : "X", 
        "L" : "X", 
        "M" : "X", 
        "N" : "X", 
        "O" : "X", 
        "P" : "X", 
        "Q" : "X", 
        "R" : "X", 
        "S" : "X", 
        "T" : "X", 
        "U" : "X", 
        "V" : "X", 
        "W" : "X", 
        "X" : "X", 
        "Y" : "X", 
        "Z" : "X", 
        "0" : "9", 
        "1" : "9", 
        "2" : "9", 
        "3" : "9", 
        "4" : "9", 
        "5" : "9", 
        "6" : "9", 
        "7" : "9", 
        "8" : "9", 
        "9" : "9"
    }
    
    for _, _, files in os.walk(rootdir):
        for file in files:

            file_to_mask = open(rootdir + file,'r')

            masked_file = open(rootdir + 'm_' + file, 'w')
            
            file_structure = input('How is this file separated? Type "'"F"'" for Fixed Width and "'"D"'" for delimited. ')
            file_structure = file_structure.upper()

            rows_to_ignore = []

            if file_structure == 'F':
                start_points = [7]
                end_points = [16]

                for ind, line in enumerate(file_to_mask,0):
                    masked_file.write(multi_masker_fixed(line, start_points, end_points, masking_cipher))
                    
                    if ind not in rows_to_ignore:
                        masked_file.write(multi_masker_fixed(line, start_points, end_points, masking_cipher))
                        # masked_file.write(multi_masker_fixed(line, [0], [len(line)], masking_cipher))
                    else:
                        masked_file.write(line)

            elif file_structure == 'D':
                delimiter = input('How is the file delimited? Please type the delimiter (e.g., "'","'", "'"|"'", etc.). ')                
                columns_to_mask = [
                    5, 6, 7, 8
                ]

                for ind, line in enumerate(file_to_mask,0):
                    if not line.startswith('D1'): rows_to_ignore.append(ind)

                    if ind not in rows_to_ignore:
                            masked_file.write(multi_masker_delimited(line, delimiter, columns_to_mask, masking_cipher))
                    else:
                            masked_file.write(line)

            file_to_mask.close()
            masked_file.close()

def multi_masker_fixed(row_to_mask, start_points, end_points, masking_cipher):
    counter_masks = 0
    masked_line = ''

    for i in range(len(row_to_mask)):
        if i >= start_points[counter_masks] and i < end_points[counter_masks]:
            upper_data_to_mask = row_to_mask[i].upper()
            if upper_data_to_mask in masking_cipher:
                masked_line = masked_line + masking_cipher[upper_data_to_mask]

            else:
                masked_line = masked_line + row_to_mask[i]

        elif i == end_points[counter_masks]:
            upper_data_to_mask = row_to_mask[i].upper()
            if upper_data_to_mask in masking_cipher:
                masked_line = masked_line + masking_cipher[upper_data_to_mask]

            else:
                masked_line = masked_line + row_to_mask[i]
            
            if counter_masks + 1 <= len(start_points) - 1:
                counter_masks = counter_masks + 1

        else:
            masked_line = masked_line + row_to_mask[i]
    
    return masked_line

def multi_masker_delimited(row_to_mask, delimiter, columns_to_mask, masking_cipher):

    masked_line = ''

    row_to_mask_data = row_to_mask.split(delimiter)

    for j in range(len(row_to_mask_data)):
        if j in columns_to_mask:
            data_to_mask = row_to_mask_data[j]

            for k in range(len(data_to_mask)):
                upper_data_to_mask = data_to_mask[k].upper()

                if upper_data_to_mask in masking_cipher:
                    masked_line = masked_line + masking_cipher[upper_data_to_mask]

                else:
                    masked_line = masked_line + data_to_mask[k]

            masked_line = masked_line + delimiter
        
        elif j == len(row_to_mask_data) - 1:
            masked_line = masked_line + row_to_mask_data[j]

        else:
            masked_line = masked_line + row_to_mask_data[j] + delimiter

    return masked_line

main()