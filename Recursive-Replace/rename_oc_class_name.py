#!/usr/bin/env python3
import sys
import glob
import pathlib
import os

from pathlib import Path

def main():
    # print (sys.argv)

    #record original path, restore cd to this path before exit.
    entrance_path = os.getcwd()

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

    # auto receive input arguments as class names
    try:
        original_class = sys.argv[1]
        print('original_class:', original_class)
        renamed_class = sys.argv[2]
        print('renamed_class:', renamed_class)
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
        original_class = input("Enter Objective-C original class name:\n")
    if renamed_class is None:
        renamed_class = input("Enter Objective-C renamed class name:\n")
    if root_path is None:
        root_path = input("Enter your project absolute path:\n")

    # NOTE: recommand add specific prefix & suffix to locate it correctly!
    # [XXX class_method]
    # @class XXX;
    #  XXX*
    #  XXX *
    # @interface XXX:
    # @interface XXX :
    # #import "XXX.h" OR // XXX.h
    # #import "XXX.m" OR // XXX.m
    # @interface XXX ()
    # #pragma mark XXX OR #pragma mark - XXX
    # @implementation XXX
    # (XXX*)
    # (XXX *)
    # @interface Child : XXX
    # @interface XXX()
    # @"XXX"
    # isKindOfClass:XXX.class]
    # XXX.method/property
    # #import "YYY/XXX.h"
    # @property (nonatomic,strong)XXX * OR @property (nonatomic,strong)XXX*
    original_formats = ['[' + original_class + ' ',
                        ' '+ original_class + ';',
                        ' ' + original_class + '*',
                        ' ' + original_class + ' *',
                        ' ' + original_class + ':',
                        ' ' + original_class + ' :',
                        ' ' + original_class + '.h',
                        ' ' + original_class + '.m',
                        '"' + original_class + '.h',
                        '"' + original_class + '.m',
                        ' ' + original_class + ' ',
                        'mark ' + original_class + ' ',
                        'mark - ' + original_class + ' ',
                        '@implementation ' + original_class + '\n',
                        '(' + original_class + '*',
                        '(' + original_class + ' *',
                        ' ' + original_class + '\n',
                        ' ' + original_class + '(',
                        '"' + original_class + '"',
                        ':' + original_class + '.',
                        ' ' + original_class + '.',
                        '/' + original_class + '.',
                        ')' + original_class + '*',
                        ')' + original_class + ' '
                        ]
    # print('original_formats:', original_formats)

    renamed_formats = ['[' + renamed_class + ' ',
                        ' '+ renamed_class + ';',
                        ' ' + renamed_class + '*',
                        ' ' + renamed_class + ' *',
                        ' ' + renamed_class + ':',
                        ' ' + renamed_class + ' :',
                        ' ' + renamed_class + '.h',
                        ' ' + renamed_class + '.m',
                        '"' + renamed_class + '.h',
                        '"' + renamed_class + '.m',
                        ' ' + renamed_class + ' ',
                        'mark ' + renamed_class + ' ',
                        'mark - ' + renamed_class + ' ',
                        '@implementation ' + renamed_class + '\n',
                        '(' + renamed_class + '*',
                        '(' + renamed_class + ' *',
                        ' ' + renamed_class + '\n',
                        ' ' + renamed_class + '(',
                        '"' + renamed_class + '"',
                        ':' + renamed_class + '.',
                        ' ' + renamed_class + '.',
                        '/' + renamed_class + '.',
                        ')' + renamed_class + '*',
                        ')' + renamed_class + ' '
                        ]
    # print('renamed_formats:', renamed_formats)

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

    # rename file name in root path
    os.chdir(root_path)
    # print(os.getcwd())

    #try:
    #    old_file_names = [original_class + ".h", original_class + ".m", original_class + ".mm", original_class + ".xib", original_class + ".storyboard"]
    #    new_file_names = [renamed_class + ".h", renamed_class + ".m", renamed_class + ".mm", renamed_class + ".xib", renamed_class + ".storyboard"]
    #    for i in range(len(old_file_names)):
    #        old_file_name=old_file_names[i]
    #        new_file_name=new_file_names[i]
    #        print('rename file:', old_file_name, 'as', new_file_name)
    #        result=os.rename(old_file_name, new_file_name)
    #        print('result:', result)
    ##        if os.path.isfile(old_file_name) and os.path.exists(old_file_name):
    ##            os.rename(old_file_name, new_file_name)
    ##        else:
    ##            print("{old_file_name} does not exist.")
    #except FileNotFoundError:
    #    print(old_file_names, "does not exist.")
    #except FileExistsError:
    #    print(new_file_names, "does exist.")

    old_file_names = [original_class + ".h", original_class + ".m", original_class + ".mm", original_class + ".xib", original_class + ".storyboard"]

    for i, original_format in enumerate(original_formats):
        renamed_format = renamed_formats[i]
        # print('will replace `', original_format, '` with `', renamed_format, '`')

    for filepath in files:
        # print(filepath)
        with open(filepath) as file:
            s = file.read()
            for i, original_format in enumerate(original_formats):
                renamed_format = renamed_formats[i]
                s = s.replace(original_format, renamed_format)
        with open(filepath, "w") as file:
            file.write(s)
        exact_file_name = filepath.name
        # print('exact_file_name:', exact_file_name)
        for i, old_file_name in enumerate(old_file_names):
            if old_file_name == exact_file_name and os.path.isfile(filepath) and os.path.exists(filepath):
                old_path=str(filepath)
                # print('old_path:', old_path)
                new_path=old_path.replace(original_class, renamed_class)
                # print('rename file:', old_path, 'to', new_path)
                os.rename(old_path, new_path)
    os.chdir(entrance_path)
    # print(os.getcwd())
    sys.exit(0)

if __name__ == "__main__":
    main()
