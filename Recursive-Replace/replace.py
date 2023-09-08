import glob
import pathlib
import sys

from pathlib import Path

#root_path = '/Users/gavinxiang/Downloads/Shell-Collection/Recursive-Replace/Test'

def main():
    # auto receive input arguments as class names
    original_class = None
    renamed_class = None
    root_path = None
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

    # remind to input class names
    if original_class is None:
        original_class = input("Enter original string:\n")
    if renamed_class is None:
        renamed_class = input("Enter replaced string:\n")
    if root_path is None:
        root_path = input("Enter your directory absolute path:\n")
    
    formats = {".txt", ".h", ".m", ".mm", ".xib", ".storyboard", ".swift"} # customize all formats files which you wanna to replace
    files = (p.resolve() for p in Path(root_path).glob("**/*") if p.suffix in formats)
    # for filepath in glob.iglob(root_path + '/**/*.txt', recursive=True):
    for filepath in files:
        # print(filepath)
        with open(filepath) as file:
            s = file.read()
            # print('before:', s)
            s = s.replace(original_class, renamed_class)
            # print('after:', s)
        with open(filepath, "w") as file:
            file.write(s)

if __name__ == "__main__":
    main()
