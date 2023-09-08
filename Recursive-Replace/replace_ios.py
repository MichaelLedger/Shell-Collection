import glob
import pathlib
import sys

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

#root_path = '/Users/gavinxiang/Downloads/Shell-Collection/Recursive-Replace/Test'

def main():
    # auto receive input arguments as class names
    try:
        original_class = sys.argv[1]
        print('original_string:', original_class)
        renamed_class = sys.argv[2]
        print('renamed_string:', renamed_class)
        root_path = sys.argv[3]
        print('root_path:', root_path)
    except:
        e = sys.exc_info()[0]
        # print('error:', e)
        original_class = None
        renamed_class = None
        root_path = None

    # remind to input class names
    if original_class is None:
        original_class = input("Enter original string:\n")
    if renamed_class is None:
        renamed_class = input("Enter replaced string:\n")
    if root_path is None:
        root_path = input("Enter your directory absolute path:\n")

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
    files = (p.resolve() for p in Path(root_path).glob("**/*") if p.suffix in {".h", ".m", ".mm", ".xib", ".storyboard", ".swift"})

    for filepath in files:
        # print(filepath)
        with open(filepath) as file:
            s = file.read()
            s = s.replace(original_class, renamed_class)
        with open(filepath, "w") as file:
            file.write(s)

if __name__ == "__main__":
    main()
