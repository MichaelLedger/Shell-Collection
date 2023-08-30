import glob
import pathlib

from pathlib import Path

#def multi_extension_glob_mask(mask_base, *extensions):
#    mask_ext = ['[{}]'.format(''.join(set(c))) for c in zip(*extensions)]
#    if not mask_ext or len(set(len(e) for e in extensions)) > 1:
#        mask_ext.append('*')
#    return mask_base + ''.join(mask_ext)

#mask = multi_extension_glob_mask('/**/*.', 'mp3', 'flac', 'wma')
#print(mask)  # /**/*.[wfm][mlp][a3]*

# *.{h,m,mm,xib,storyboard,swift}
#mask = multi_extension_glob_mask('/**/*.', 'h', 'm', 'mm', 'xib', 'storyboard', 'swift')
#print(mask)  # /**/*.[sxmh]*

root_path = '/Users/gavinxiang/Downloads/freeprints_ios_4/PhotoBooks/MyDealsSDK'

#types = ('*.h', '*.m','*.mm', '*.xib', '*.storyboard', '*.swift') # the tuple of file types
#for type in types:
#    for filepath in glob.iglob(root_path + '/**/' + type, recursive=True):
#        print(filepath)
#        with open(filepath) as file:
#            s = file.read()
#            s = s.replace('Hello', 'Hi')
#        with open(filepath, "w") as file:
#            file.write(s)

#So many answers that suggest globbing as many times as number of extensions, I'd prefer globbing just once instead:
files = (p.resolve() for p in Path(root_path).glob("**/*") if p.suffix in {".h", ".m", ".mm", ".xib", ".storyboard"})

original_class = "WDPage"
renamed_class = "FPBWDPage"

# [XXX class_method]
# @class XXX;
# XXX*
# XXX *
# @interface XXX:
# @interface XXX :
# #import "XXX.h" OR // XXX.h
# #import "XXX.m" OR // XXX.m
original_formats = ['[' + original_class + ' ', ' '+ original_class + ';', original_class + '*', original_class + ' *', original_class + ':', original_class + ' :', original_class + '.h', original_class + '.m']
print('original_formats:', original_formats)
renamed_formats = ['[' + renamed_class + ' ', ' '+ renamed_class + ';', renamed_class + '*', renamed_class + ' *', renamed_class + ':', renamed_class + ' :', renamed_class + '.h', renamed_class + '.m']
print('renamed_formats:', renamed_formats)

for i, original_format in enumerate(original_formats):
    renamed_format = renamed_formats[i]
    print('will replace `', original_format, '` with `', renamed_format, '`')

for filepath in files:
    print(filepath)
    with open(filepath) as file:
        s = file.read()
        for i, original_format in enumerate(original_formats):
            renamed_format = renamed_formats[i]
            s = s.replace(original_format, renamed_format)
    with open(filepath, "w") as file:
        file.write(s)
